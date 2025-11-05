#!/usr/bin/env node

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

import { TGW_MAP, TEST_TARGETS, REGIONS, type TestTarget } from './config.ts';

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
  account: string;
  vpcId?: string;
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
  ec2: EC2Client
): Promise<LambdaInfo[]> {
  const taggingClient = new ResourceGroupsTaggingAPIClient({
    region,
    credentials: creds,
  });

  const lambdaClient = new LambdaClient({
    region,
    credentials: creds,
  });

  // Query for lambdas with connectivity_check tags
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

    // Extract function name from ARN
    const arnParts = resource.ResourceARN.split(':');
    const functionName = arnParts[arnParts.length - 1];

    const fnConfig = await lambdaClient.send(
      new GetFunctionCommand({ FunctionName: functionName })
    );

    const subnetIds = fnConfig.Configuration?.VpcConfig?.SubnetIds || [];
    const account = arnParts[4];

    if (subnetIds.length > 0) {
      // Get VPC ID from first subnet
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

  // Check for function errors
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

  // Verify it's an array
  if (!Array.isArray(parsed)) {
    throw new Error(`Lambda returned non-array response: ${resultStr}`);
  }

  return parsed;
}

// Main
const token = process.argv[2];
const ddis = process.argv.slice(3);

if (!token || ddis.length === 0) {
  console.error(
    'Usage: ts-node script.ts <API_TOKEN> <DDI1> [DDI2] [DDI3] ...'
  );
  process.exit(1);
}

const allResults: ConnectivityTestResult[] = [];

for (const ddi of ddis) {
  console.log(`\nProcessing DDI ${ddi}...`);
  const accounts = await getAwsAccounts(ddi, token);
  console.log(`Found ${accounts.length} accounts`);

  for (const account of accounts) {
    console.log(`\n  Account: ${account.name} (${account.awsAccountNumber})`);
    const creds = await getCreds(ddi, account.awsAccountNumber, token);

    for (const region of REGIONS) {
      const tgwId = TGW_MAP[region];
      if (!tgwId) continue;

      console.log(`    Region: ${region}`);

      const ec2 = new EC2Client({ region, credentials: creds });

      // Find VPCs attached to TGW
      const tgwVpcs = await findTgwVpcs(
        ec2,
        tgwId,
        region,
        account.awsAccountNumber
      );

      if (tgwVpcs.length === 0) {
        console.log(`      No VPCs attached to ${tgwId}`);
        continue;
      }

      console.log(`      Found ${tgwVpcs.length} VPCs attached to TGW:`);
      for (const vpc of tgwVpcs) {
        console.log(`        - ${vpc.vpcId} (${vpc.vpcName})`);
      }

      // Find subnets routing to TGW (for reporting purposes)
      const tgwSubnets = await findTgwSubnets(
        ec2,
        tgwId,
        region,
        account.awsAccountNumber
      );
      console.log(
        `      Found ${tgwSubnets.length} subnets with routes to TGW`
      );

      // Find connectivity check lambdas
      const lambdas = await findConnectivityLambdas(region, creds, ec2);
      console.log(`      Found ${lambdas.length} connectivity check lambdas:`);
      for (const lambda of lambdas) {
        console.log(
          `        - ${lambda.functionName} in VPC ${
            lambda.vpcId
          } (subnets: ${lambda.subnetIds.join(', ')})`
        );
      }

      // Filter lambdas that are in TGW VPCs
      const tgwVpcIds = new Set(tgwVpcs.map((v) => v.vpcId));
      const relevantLambdas = lambdas.filter(
        (lambda) => lambda.vpcId && tgwVpcIds.has(lambda.vpcId)
      );

      console.log(
        `      ${relevantLambdas.length} lambdas deployed in TGW VPCs`
      );

      // Invoke each lambda
      for (const lambda of relevantLambdas) {
        console.log(`        Testing ${lambda.functionName}...`);

        // Get VPC name for reporting
        const vpcInfo = tgwVpcs.find((v) => v.vpcId === lambda.vpcId);
        const vpcName = vpcInfo?.vpcName || lambda.vpcId || 'unknown';

        try {
          const results = await invokeLambda(lambda, creds, TEST_TARGETS);

          allResults.push({
            lambda,
            vpcName,
            results,
          });

          const successCount = results.filter((r) => r.success).length;
          console.log(
            `          ${successCount}/${results.length} tests passed`
          );
        } catch (err) {
          console.log(
            `          Error: ${
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
}

// Output summary
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
    console.log(`\nLambda: ${result.lambda.functionName}`);
    console.log(`VPC: ${result.vpcName} (${result.lambda.vpcId})`);
    console.log(`Lambda Subnets: ${result.lambda.subnetIds.join(', ')}`);
    console.log(`Account: ${result.lambda.account}`);

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
