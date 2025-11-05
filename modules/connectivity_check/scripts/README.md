# TGW Connectivity Tester

A script to test network connectivity through AWS Transit Gateways by automatically discovering and invoking connectivity check Lambda functions deployed in VPCs attached to specified Transit Gateways.

## What It Does

1. Finds all VPCs attached to specified Transit Gateways across multiple AWS accounts and regions
2. Discovers Lambda functions tagged with `connectivity_check: "true"` deployed in those VPCs
3. Invokes each Lambda with configured test targets (hosts/ports to test)
4. Aggregates and reports results showing which connectivity tests passed or failed

## Prerequisites

- Node.js 24+ with TypeScript support
- Rackspace API token for fetching AWS credentials
- Connectivity check Lambda functions deployed using the `connectivity_check` Terraform module
- Lambda functions must be tagged with:
  - `connectivity_check: "true"`
  - `connectivity_check_version: "v1"`

## Configuration

Edit the `config.ts` file to configure:

1. **Transit Gateway IDs** (`TGW_MAP`):

   The script searches for attachments to TGWs in given accounts/regions, and finds lambdas which route through them.

   ```typescript
   const TGW_MAP: Record<string, string> = {
     'us-east-1': 'tgw-xxxxx',
     'us-east-2': 'tgw-yyyyy',
     // ...
   };
   ```

2. **Test Targets** (`TEST_TARGETS`):

   List of targets to check connectivity with.

   ```typescript
   const TEST_TARGETS = [
     { host: 'example.com', port: 443, protocol: 'https' },
     { host: '10.0.1.100', port: 5432, protocol: 'tcp' }
   ];
   ```

3. **Regions** (`REGIONS`):

   Limit to only the regions you know you have may have relevant infrastructure in.

   ```typescript
   const REGIONS = ['us-east-1', 'us-east-2', 'us-west-1', 'us-west-2'];
   ```

## Installation

```bash
npm install
```

## Usage

The script now uses modern command-line argument parsing with named options:

### Basic Usage

```bash
node test-connectivity.ts --token <RACKSPACE_API_TOKEN> [options]
```

### Required Arguments

- `--token` or `-t`: Rackspace API token for fetching AWS credentials

### Input Options (at least one required)

- `--ddi <ddi>`: DDI number (can be specified multiple times)
- `--awsAccountNumber <account>`: AWS account number (can be specified multiple times)

### Optional Arguments

- `--region <region>`: AWS region to test (can be specified multiple times, defaults to all configured regions)
- `--help` or `-h`: Show help message

### Examples

**Test specific DDIs in default regions:**

```bash
node test-connectivity.ts --token $(tok -nq racker) --ddi 12345 --ddi 67890
```

**Test specific AWS account numbers in specific regions:**

```bash
node test-connectivity.ts --token $(tok -nq racker) \
  --awsAccountNumber 111111111111 \
  --awsAccountNumber 222222222222 \
  --region us-east-1 \
  --region us-west-2
```

**Test both DDIs and account numbers:**

```bash
node test-connectivity.ts --token $(tok -nq racker) \
  --ddi 12345 \
  --awsAccountNumber 111111111111 \
  --region us-west-2
```

**Get help:**

```bash
node test-connectivity.ts --help
```

## Output

The script outputs:

1. **Progress logs** showing VPCs, subnets, and Lambda functions discovered
2. **Test execution** showing pass/fail counts for each Lambda
3. **Summary report** grouped by region with detailed results including:
   - Lambda function names and locations
   - Test results with latency, resolved IPs, HTTP status codes
   - Error details for failed tests

**Example output:**

```plain
=== CONNECTIVITY TEST SUMMARY ===

US-WEST-2
==================================================

Lambda: connectivity-test-subnet-abc123
VPC: production-vpc (vpc-123456)
Lambda Subnets: subnet-abc123, subnet-def456
Account: 111111111111

Test Results:
  ✓ https://example.com:443 - 145ms (HTTP 200)
    Resolved to: 93.184.216.34
  ✗ tcp://10.0.1.100:5432 - connect ETIMEDOUT (ETIMEDOUT)
    Resolved to: 10.0.1.100
```

## Troubleshooting

- **No lambdas found**: Ensure Lambda functions are tagged correctly with `connectivity_check: "true"`
- **Lambda invocation fails**: Check Lambda has proper VPC networking permissions and security group rules
- **No VPCs attached to TGW**: Verify Transit Gateway ID is correct for the region
- **Authentication errors**: Verify Rackspace API token is valid and has access to specified DDIs
- **Missing required arguments**: The script requires either `--ddi` or `--awsAccountNumber` options, and always requires `--token`
- **Invalid input format**: DDI and AWS account numbers must contain only numeric characters (account numbers can start with 0)
- **Credential access errors**: When using `--awsAccountNumber`, the script will automatically look up the associated DDI for credential access
