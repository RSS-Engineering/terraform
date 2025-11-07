#!/usr/bin/env node

import { parseArgs } from 'node:util';
import {
  EC2Client,
  DescribeTransitGatewayVpcAttachmentsCommand,
  DescribeRouteTablesCommand,
  DescribeSubnetsCommand,
  DescribeVpcsCommand,
} from '@aws-sdk/client-ec2';
import {
  LambdaClient,
  GetFunctionCommand,
  InvokeCommand,
} from '@aws-sdk/client-lambda';
import {
  ResourceGroupsTaggingAPIClient,
  GetResourcesCommand,
} from '@aws-sdk/client-resource-groups-tagging-api';

import {
  TGW_MAP,
  TEST_TARGETS,
  REGIONS,
  SHARED_SUBNET_ACCOUNTS,
  type TestTarget,
} from './config.ts';

interface RackspaceCredential {
  accessKeyId: string;
  secretAccessKey: string;
  sessionToken: string;
}

interface SubnetInfo {
  subnetId: string;
  cidr: string;
  vpcId: string;
  vpcName: string;
  region: string;
  account: string;
}

interface LambdaInfo {
  functionName: string;
  functionArn: string;
  subnetIds: string[];
  region: string;
  account: AwsAccount;
  vpcId?: string;
  discoveryMethod?: 'tgw' | 'shared-subnet';
}

interface TestResult {
  host: string;
  port: number;
  protocol: string;
  success: boolean;
  latencyMs?: number;
  resolvedIp?: string;
  error?: string;
  errorCode?: string;
  httpStatus?: number;
}

interface ConnectivityTestResult {
  lambda: LambdaInfo;
  vpcName: string;
  results: TestResult[];
  error?: string;
}

interface ParsedArgs {
  ddis: string[];
  awsAccountNumbers: string[];
  regions: string[];
  token: string;
}

interface AwsAccount {
  awsAccountNumber: string;
  awsAccountName?: string;
  ddi: string;
}

function validateNumericString(value: string, fieldName: string): void {
  if (!/^\d+$/.test(value)) {
    throw new Error(`${fieldName} must contain only numeric characters: ${value}`);
  }
}

function parseCliArgs(): ParsedArgs {
  const { values } = parseArgs({
    options: {
      ddi: { type: 'string', multiple: true },
      'awsAccountNumber': { type: 'string', short: 'a', multiple: true },
      region: { type: 'string', multiple: true },
      token: { type: 'string', short: 't' },
      help: { type: 'boolean', short: 'h' },
    },
    allowPositionals: false,
  });

  if (values.help) {
    printHelp();
    process.exit(0);
  }

  const token = values.token as string;
  if (!token) {
    console.error('Missing required argument: --token');
    printHelp();
    process.exit(1);
  }

  const ddis = (values.ddi as string[]) || [];
  const awsAccountNumbers = (values['awsAccountNumber'] as string[]) || [];

  if (ddis.length === 0 && awsAccountNumbers.length === 0) {
    console.error('At least one --ddi or --awsAccountNumber must be provided');
    printHelp();
    process.exit(1);
  }

  // Validate that DDIs and account numbers are numeric
  ddis.forEach(ddi => validateNumericString(ddi, 'DDI'));
  awsAccountNumbers.forEach(accountNumber => validateNumericString(accountNumber, 'AWS Account Number'));

  const regions = (values.region as string[]) || REGIONS;

  return {
    ddis,
    awsAccountNumbers,
    regions,
    token,
  };
}

function printHelp() {
  console.log(`
TGW Connectivity Tester

Tests network connectivity through AWS Transit Gateways by discovering and invoking
connectivity check Lambda functions deployed in VPCs attached to specified Transit Gateways.

Usage:
  node test-connectivity.ts --token <RACKSPACE_API_TOKEN> [options]

Required:
  -t, --token <token>               Rackspace API token for fetching AWS credentials

Input Options (at least one required):
  --ddi <ddi>                       DDI number (can be specified multiple times)
  -a, --awsAccountNumber <account>  AWS account number (can be specified multiple times)

Optional:
  --region <region>                 AWS region to test (can be specified multiple times)
                                   Default: ${REGIONS.join(', ')}
  -h, --help                       Show this help message

Examples:
  # Test specific DDIs in default regions
  node test-connectivity.ts --token $(tok -nq racker) --ddi 12345 --ddi 67890

  # Test specific AWS account numbers in specific regions
  node test-connectivity.ts --token $(tok -nq racker) \\
    --awsAccountNumber 111111111111 \\
    --awsAccountNumber 222222222222 \\
    --region us-east-1 \\
    --region us-west-2

  # Test both DDIs and account numbers
  node test-connectivity.ts --token $(tok -nq racker) \\
    --ddi 12345 \\
    --awsAccountNumber 111111111111 \\
    --region us-west-2

Notes:
  - DDIs are collections of AWS accounts; the script will fetch all associated accounts
  - AWS account numbers must be numeric strings (can start with 0)
  - When both DDIs and account numbers are provided, accounts are merged (duplicates removed)
  - For direct account numbers, the script will automatically look up the associated DDI
  - Lambda functions must be tagged with connectivity_check: "true"
  `);
}

async function getAwsAccounts(ddi: string, token: string): Promise<any[]> {
  const res = await fetch(
    `https://accounts.api.manage.rackspace.com/v0/awsAccounts`,
    {
      headers: {
        'X-Tenant-Id': ddi,
        'X-Auth-Token': token,
      },
    }
  );

  const data = await res.json();
  return data.awsAccounts;
}

async function getAwsAccount(
  awsAccountNumber: string,
  token: string
): Promise<any> {
  const res = await fetch(
    `https://accounts.api.manage.rackspace.com/v0/awsAccounts/search?criteria=${awsAccountNumber}`,
    {
      headers: {
        'X-Auth-Token': token,
      },
    }
  );

  if (!res.ok) {
    throw new Error(
      `Failed to search for AWS account ${awsAccountNumber}: ${res.status} ${res.statusText}`
    );
  }

  const data = await res.json();

  if (!data.results || !Array.isArray(data.results)) {
    throw new Error(
      `Invalid response format when searching for AWS account ${awsAccountNumber}`
    );
  }

  const matchingResult = data.results.find(
    (result: any) => result.awsAccount?.awsAccountNumber === awsAccountNumber
  );

  if (!matchingResult) {
    throw new Error(`AWS account ${awsAccountNumber} not found in any DDI`);
  }

  if (!matchingResult.awsAccount?.ddi) {
    throw new Error(`DDI not found for AWS account ${awsAccountNumber}`);
  }

  return matchingResult.awsAccount;
}

async function getCreds(
  ddi: string,
  awsAccountNumber: string,
  token: string
): Promise<RackspaceCredential> {
  const res = await fetch(
    `https://accounts.api.manage.rackspace.com/v0/awsAccounts/${awsAccountNumber}/credentials`,
    {
      method: 'POST',
      headers: {
        'X-Tenant-Id': ddi,
        'X-Auth-Token': token,
      },
    }
  );

  const data = await res.json();
  return {
    accessKeyId: data.credential.accessKeyId,
    secretAccessKey: data.credential.secretAccessKey,
    sessionToken: data.credential.sessionToken,
  };
}

async function findTgwVpcs(
  ec2: EC2Client,
  tgwId: string,
  region: string,
  accountNumber: string
): Promise<{ vpcId: string; vpcName: string }[]> {
  const attachments = await ec2.send(
    new DescribeTransitGatewayVpcAttachmentsCommand({
      Filters: [{ Name: 'transit-gateway-id', Values: [tgwId] }],
    })
  );

  const vpcs: { vpcId: string; vpcName: string }[] = [];

  for (const att of attachments.TransitGatewayVpcAttachments || []) {
    const vpcId = att.VpcId;
    if (!vpcId) continue;

    const vpcDetails = await ec2.send(
      new DescribeVpcsCommand({ VpcIds: [vpcId] })
    );
    const vpcName =
      vpcDetails.Vpcs?.[0]?.Tags?.find((t) => t.Key === 'Name')?.Value || vpcId;

    vpcs.push({ vpcId, vpcName });
  }

  return vpcs;
}

async function findTgwSubnets(
  ec2: EC2Client,
  tgwId: string,
  region: string,
  accountNumber: string
): Promise<SubnetInfo[]> {
  const attachments = await ec2.send(
    new DescribeTransitGatewayVpcAttachmentsCommand({
      Filters: [{ Name: 'transit-gateway-id', Values: [tgwId] }],
    })
  );

  const results: SubnetInfo[] = [];

  for (const att of attachments.TransitGatewayVpcAttachments || []) {
    const vpcId = att.VpcId;
    if (!vpcId) continue;

    const vpcs = await ec2.send(new DescribeVpcsCommand({ VpcIds: [vpcId] }));
    const vpcName =
      vpcs.Vpcs?.[0]?.Tags?.find((t) => t.Key === 'Name')?.Value || vpcId;

    const routeTables = await ec2.send(
      new DescribeRouteTablesCommand({
        Filters: [{ Name: 'vpc-id', Values: [vpcId] }],
      })
    );

    const subnetIds = new Set<string>();
    for (const rt of routeTables.RouteTables || []) {
      const hasTgwRoute = rt.Routes?.some((r) => r.TransitGatewayId === tgwId);
      if (hasTgwRoute) {
        rt.Associations?.forEach((a) => {
          if (a.SubnetId) subnetIds.add(a.SubnetId);
        });
      }
    }

    if (subnetIds.size > 0) {
      const subnets = await ec2.send(
        new DescribeSubnetsCommand({
          SubnetIds: Array.from(subnetIds),
        })
      );

      for (const subnet of subnets.Subnets || []) {
        if (subnet.CidrBlock && subnet.SubnetId) {
          results.push({
            subnetId: subnet.SubnetId,
            cidr: subnet.CidrBlock,
            vpcId,
            vpcName,
            region,
            account: accountNumber,
          });
        }
      }
    }
  }

  return results;
}

async function findConnectivityLambdas(
  region: string,
  creds: RackspaceCredential,
  ec2: EC2Client,
  account: AwsAccount
): Promise<LambdaInfo[]> {
  const taggingClient = new ResourceGroupsTaggingAPIClient({
    region,
    credentials: creds,
  });

  const lambdaClient = new LambdaClient({
    region,
    credentials: creds,
  });

  const resources = await taggingClient.send(
    new GetResourcesCommand({
      TagFilters: [
        { Key: 'connectivity_check', Values: ['true'] },
        { Key: 'connectivity_check_version', Values: ['v1'] },
      ],
      ResourceTypeFilters: ['lambda:function'],
    })
  );

  const lambdas: LambdaInfo[] = [];

  for (const resource of resources.ResourceTagMappingList || []) {
    if (!resource.ResourceARN) continue;

    const arnParts = resource.ResourceARN.split(':');
    const functionName = arnParts[arnParts.length - 1];

    const fnConfig = await lambdaClient.send(
      new GetFunctionCommand({ FunctionName: functionName })
    );

    const subnetIds = fnConfig.Configuration?.VpcConfig?.SubnetIds || [];

    if (subnetIds.length > 0) {
      const subnetDetails = await ec2.send(
        new DescribeSubnetsCommand({ SubnetIds: [subnetIds[0]] })
      );
      const vpcId = subnetDetails.Subnets?.[0]?.VpcId;

      lambdas.push({
        functionName,
        functionArn: resource.ResourceARN,
        subnetIds,
        region,
        account,
        vpcId,
      });
    }
  }

  return lambdas;
}

async function findSharedSubnets(ec2: EC2Client, region: string): Promise<string[]> {
  const sharedSubnets: string[] = [];

  for (const ownerId of SHARED_SUBNET_ACCOUNTS) {
    try {
      const subnets = await ec2.send(
        new DescribeSubnetsCommand({
          Filters: [{ Name: 'owner-id', Values: [ownerId] }],
        })
      );

      for (const subnet of subnets.Subnets || []) {
        if (subnet.SubnetId) {
          sharedSubnets.push(subnet.SubnetId);
        }
      }
    } catch (err) {
      throw new Error(
        `Failed to describe subnets for shared account ${ownerId} in region ${region}: ${
          err instanceof Error ? err.message : 'Unknown error'
        }`
      );
    }
  }

  return sharedSubnets;
}

async function invokeLambda(
  lambda: LambdaInfo,
  creds: RackspaceCredential,
  targets: TestTarget[]
): Promise<TestResult[]> {
  const lambdaClient = new LambdaClient({
    region: lambda.region,
    credentials: creds,
  });

  const response = await lambdaClient.send(
    new InvokeCommand({
      FunctionName: lambda.functionName,
      Payload: JSON.stringify({ targets }),
    })
  );

  if (response.FunctionError) {
    const errorPayload = response.Payload
      ? new TextDecoder().decode(response.Payload)
      : 'Unknown error';
    throw new Error(
      `Lambda execution failed: ${response.FunctionError} - ${errorPayload}`
    );
  }

  if (!response.Payload) {
    throw new Error('No payload returned from Lambda');
  }

  const resultStr = new TextDecoder().decode(response.Payload);
  const parsed = JSON.parse(resultStr);

  if (!Array.isArray(parsed)) {
    throw new Error(`Lambda returned non-array response: ${resultStr}`);
  }

  return parsed;
}

const args = parseCliArgs();
const allResults: ConnectivityTestResult[] = [];

// Collect all unique AWS accounts with their associated DDIs
const awsAccounts = new Map<string, AwsAccount>();

// For each DDI, fetch associated AWS accounts and add to the map
for (const ddi of args.ddis) {
  console.log(`\nProcessing DDI ${ddi}...`);
  const accounts = await getAwsAccounts(ddi, args.token);
  console.log(`Found ${accounts.length} accounts for DDI ${ddi}`);

  for (const account of accounts) {
    awsAccounts.set(account.awsAccountNumber, {
      awsAccountNumber: account.awsAccountNumber,
      awsAccountName: account.name,
      ddi: ddi
    });
  }
}

// For direct AWS account numbers, look up their DDIs
for (const awsAccountNumber of args.awsAccountNumbers) {
  if (!awsAccounts.has(awsAccountNumber)) {
    console.log(`\nLooking up DDI for AWS account ${awsAccountNumber}...`);
    try {
      const awsAccount = await getAwsAccount(awsAccountNumber, args.token);
      awsAccounts.set(awsAccountNumber, {
        awsAccountNumber: awsAccountNumber,
        awsAccountName: awsAccount.name,
        ddi: awsAccount.ddi
      });
      console.log(`Found DDI ${awsAccount.ddi} for account ${awsAccountNumber}`);
    } catch (error) {
      console.error(`Failed to find DDI for account ${awsAccountNumber}: ${error instanceof Error ? error.message : 'Unknown error'}`);
      process.exit(1);
    }
  } else {
    console.log(`AWS account ${awsAccountNumber} already associated with DDI ${awsAccounts.get(awsAccountNumber)!.ddi}`);
  }
}

console.log(`\nTotal unique AWS accounts to process: ${awsAccounts.size}`);
console.log(`Regions to test: ${args.regions.join(', ')}`);

// Process each unique AWS account
for (const awsAccount of awsAccounts.values()) {
  console.log(`\n=== Processing AWS Account: ${awsAccount.awsAccountNumber} (DDI: ${awsAccount.ddi}) ===`);

  const creds = await getCreds(awsAccount.ddi, awsAccount.awsAccountNumber, args.token);

  for (const region of args.regions) {
    const tgwId = TGW_MAP[region];
    if (!tgwId) {
      console.log(`  Skipping ${region}: No TGW configured`);
      continue;
    }

    console.log(`  Region: ${region}`);

    const ec2 = new EC2Client({ region, credentials: creds });

    // Find VPCs attached to TGW
    const tgwVpcs = await findTgwVpcs(
      ec2,
      tgwId,
      region,
      awsAccount.awsAccountNumber
    );

    // Get shared subnets for filtering
    const sharedSubnets = await findSharedSubnets(ec2, region);
    if (sharedSubnets.length === 0) {
      console.log(`    No shared subnets found in region`);
    } else {
      console.log(`    Found ${sharedSubnets.length} shared subnets in region`);
      console.log(`    Shared Subnets: ${sharedSubnets.join(', ')}`);
    }

    if (tgwVpcs.length === 0) {
      console.log(`    No VPCs attached to ${tgwId}`);
    } else {
      console.log(`    Found ${tgwVpcs.length} VPCs attached to TGW:`);
      for (const vpc of tgwVpcs) {
        console.log(`      - ${vpc.vpcId} (${vpc.vpcName})`);
      }
    }

    if (tgwVpcs.length === 0 && sharedSubnets.length === 0) {
      console.log(`    No TGW VPCs or shared subnets found; skipping region`);
      continue;
    }

    // Find subnets routing to TGW (for reporting purposes)
    const tgwSubnets = await findTgwSubnets(
      ec2,
      tgwId,
      region,
      awsAccount.awsAccountNumber
    );
    console.log(`    Found ${tgwSubnets.length} subnets with routes to TGW`);

    // Find all connectivity check lambdas in the region
    const allLambdas = await findConnectivityLambdas(region, creds, ec2, awsAccount);
    console.log(
      `    Found ${allLambdas.length} total connectivity check lambdas in region`
    );

    // Filter lambdas by TGW VPCs
    const tgwVpcIds = new Set(tgwVpcs.map((v) => v.vpcId));
    const tgwLambdas = allLambdas
      .filter((lambda) => lambda.vpcId && tgwVpcIds.has(lambda.vpcId))
      .map((lambda) => ({ ...lambda, discoveryMethod: 'tgw' as const }));

    // Filter lambdas by shared subnets
    const sharedSubnetLambdas = allLambdas
      .filter((lambda) =>
        lambda.subnetIds.some((subnetId) => sharedSubnets.includes(subnetId))
      )
      .map((lambda) => ({
        ...lambda,
        discoveryMethod: 'shared-subnet' as const,
      }));

    console.log(`    ${tgwLambdas.length} lambdas deployed in TGW VPCs`);
    console.log(
      `    ${sharedSubnetLambdas.length} lambdas deployed in shared subnets`
    );

    // Combine and deduplicate lambdas by ARN
    const combinedLambdas = [...tgwLambdas, ...sharedSubnetLambdas];
    const uniqueLambdas = combinedLambdas.reduce((acc, lambda) => {
      if (
        !acc.some((existing) => existing.functionArn === lambda.functionArn)
      ) {
        acc.push(lambda);
      }
      return acc;
    }, [] as LambdaInfo[]);

    console.log(`    Total unique lambdas to test: ${uniqueLambdas.length}`);

    for (const lambda of uniqueLambdas) {
      const method =
        lambda.discoveryMethod === 'shared-subnet' ? '(shared)' : '(TGW)';
      console.log(
        `      - ${lambda.functionName} ${method} in VPC ${
          lambda.vpcId
        } (subnets: ${lambda.subnetIds.join(', ')})`
      );
    }

    // Invoke each lambda
    for (const lambda of uniqueLambdas) {
      const method =
        lambda.discoveryMethod === 'shared-subnet' ? '(shared)' : '(TGW)';
      console.log(`      Testing ${lambda.functionName} ${method}...`);

      // Get VPC name for reporting
      let vpcName = lambda.vpcId || 'unknown';
      if (lambda.discoveryMethod === 'tgw') {
        const vpcInfo = tgwVpcs.find((v) => v.vpcId === lambda.vpcId);
        vpcName = vpcInfo?.vpcName || lambda.vpcId || 'unknown';
      } else {
        // For shared subnet lambdas, try to get VPC name via EC2
        if (lambda.vpcId) {
          try {
            const vpcDetails = await ec2.send(
              new DescribeVpcsCommand({ VpcIds: [lambda.vpcId] })
            );
            vpcName =
              vpcDetails.Vpcs?.[0]?.Tags?.find((t) => t.Key === 'Name')
                ?.Value || lambda.vpcId;
          } catch {
            vpcName = lambda.vpcId;
          }
        }
      }

      try {
        const results = await invokeLambda(lambda, creds, TEST_TARGETS);

        allResults.push({
          lambda,
          vpcName,
          results,
        });

        const successCount = results.filter((r) => r.success).length;
        console.log(`        ${successCount}/${results.length} tests passed`);
      } catch (err) {
        console.log(
          `        Error: ${
            err instanceof Error ? err.message : 'Unknown error'
          }`
        );

        allResults.push({
          lambda,
          vpcName,
          results: [],
          error: err instanceof Error ? err.message : 'Unknown error',
        });
      }
    }
  }
}

console.log('\n\n=== CONNECTIVITY TEST SUMMARY ===\n');

const byRegion: Record<string, ConnectivityTestResult[]> = {};
for (const result of allResults) {
  if (!byRegion[result.lambda.region]) {
    byRegion[result.lambda.region] = [];
  }
  byRegion[result.lambda.region].push(result);
}

for (const region of Object.keys(byRegion).sort()) {
  console.log(`\n${region.toUpperCase()}`);
  console.log('='.repeat(50));

  for (const result of byRegion[region]) {
    const method = result.lambda.discoveryMethod === 'shared-subnet' ? 'Shared Subnet' : 'TGW';
    console.log(`\nLambda: ${result.lambda.functionName} (${method})`);
    console.log(`VPC: ${result.vpcName} (${result.lambda.vpcId})`);
    console.log(`Lambda Subnets: ${result.lambda.subnetIds.join(', ')}`);
    console.log(`Account: ${result.lambda.account.awsAccountNumber} (${result.lambda.account.awsAccountName})`);

    if (result.error) {
      console.log(`ERROR: ${result.error}`);
    } else {
      console.log('\nTest Results:');
      for (const test of result.results) {
        const status = test.success ? '✓' : '✗';
        const details = test.success
          ? `${test.latencyMs}ms${
              test.httpStatus ? ` (HTTP ${test.httpStatus})` : ''
            }`
          : `${test.error} (${test.errorCode})`;
        console.log(
          `  ${status} ${test.protocol}://${test.host}:${test.port} - ${details}`
        );
        if (test.resolvedIp) {
          console.log(`    Resolved to: ${test.resolvedIp}`);
        }
      }
    }
  }
}

console.log(
  `\n\nTotal tests run: ${allResults.length} lambdas across ${
    Object.keys(byRegion).length
  } regions`
);
