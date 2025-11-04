# connectivity_check

**connectivity_check** deploys a Lambda function to test network connectivity from VPC subnets. Designed for validating connectivity through Transit Gateways without manual testing via EC2 instances.

## Example Usage

---

### Basic connectivity testing

```terraform
module "connectivity_test" {
  source = "git@github.com:RSS-Engineering/terraform//modules/connectivity_check?ref=<commit>"

  subnet_ids         = ["subnet-12345678", "subnet-87654321"]
  security_group_ids = ["sg-abcdef12"]
}
```

### Custom function configuration

```terraform
module "connectivity_test" {
  source = "git@github.com:RSS-Engineering/terraform//modules/connectivity_check?ref=<commit>"

  function_name       = "my-connectivity-test"
  subnet_ids          = ["subnet-12345678"]
  security_group_ids  = ["sg-abcdef12"]
  timeout             = 60
  memory_size         = 256
  log_retention_days  = 7
}
```

## Argument Reference

---

The following arguments are supported:

- `subnet_ids` - (Required) List of subnet IDs where the Lambda function will be deployed.
- `security_group_ids` - (Required) List of security group IDs to attach to the Lambda function.
- `function_name` - (Optional) Name of the Lambda function. Defaults to "connectivity-test-{subnet-ids}".
- `timeout` - (Optional) Lambda function timeout in seconds. Default is 30.
- `memory_size` - (Optional) Lambda function memory in MB. Default is 128.
- `log_retention_days` - (Optional) CloudWatch log retention in days. Default is 30.

## Attributes Reference

---

In addition to all arguments above, the following attributes are exported:

- `function_name` - Name of the Lambda function
- `function_arn` - ARN of the Lambda function
- `function_invoke_arn` - Invoke ARN of the Lambda function
- `log_group_name` - CloudWatch Log Group name

## Usage

---

The Lambda function accepts a payload with targets to test:

```json
{
  "targets": [
    {
      "host": "example.com",
      "port": 443,
      "protocol": "https",
      "path": "/health"
    },
    {
      "host": "database.internal",
      "port": 5432,
      "protocol": "tcp"
    }
  ]
}
```

Returns structured results with success/failure, latency, resolved IPs, error details, and HTTP status codes:

```json
[
  {
    "host": "example.com",
    "port": 443,
    "protocol": "https",
    "success": true,
    "resolvedIp": "93.184.216.34",
    "latencyMs": 245,
    "httpStatus": 200
  },
  {
    "host": "database.internal",
    "port": 5432,
    "protocol": "tcp",
    "success": false,
    "resolvedIp": "10.0.1.100",
    "error": "Connection refused",
    "errorCode": "ECONNREFUSED"
  }
]
```
