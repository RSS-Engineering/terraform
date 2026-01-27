# Connectivity Check Module

Terraform module for deploying a Lambda function that tests TCP and HTTPS connectivity to specified endpoints and publishes metrics to Datadog.

## Lambda Package

The Lambda function uses a pre-built package (`lambda.zip`) that includes the `@janus.team/janus-core` dependency. This approach ensures the module works across all consuming repositories without requiring npm authentication during terraform apply.

### Rebuilding the Lambda Package

If you modify the Lambda code or dependencies:

```bash
cd modules/connectivity_check
./scripts/build-lambda.sh
```

The GitHub Actions workflow will automatically rebuild the package when changes are pushed to the `lambda/` directory.

## Usage

```hcl
module "connectivity_check" {
  source = "git@github.com:RSS-Engineering/terraform//modules/connectivity_check?ref=<commit-sha>"
  
  function_name      = "connectivity-check-primary"
  subnet_ids         = ["subnet-xxx", "subnet-yyy"]
  security_group_ids = ["sg-xxx"]
  
  enable_monitoring   = true
  monitoring_schedule = "rate(1 minute)"
  monitoring_targets = [
    {
      host     = "example.com"
      port     = 443
      protocol = "https"
      critical = true
    }
  ]
  
  datadog_api_key   = var.datadog_api_key
  janus_environment = var.environment
}
```

## Requirements

- Terraform >= 1.0
- AWS Provider >= 5.0

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| function_name | Name of the Lambda function | string | - | yes |
| subnet_ids | List of subnet IDs for Lambda | list(string) | - | yes |
| security_group_ids | List of security group IDs | list(string) | - | yes |
| enable_monitoring | Enable scheduled monitoring | bool | false | no |
| monitoring_schedule | EventBridge schedule expression | string | "rate(1 minute)" | no |
| monitoring_targets | List of endpoints to monitor | list(object) | [] | no |
| datadog_api_key | Datadog API key | string | "" | no |
| janus_environment | Environment name | string | "unknown" | no |
| timeout | Lambda timeout in seconds | number | 10 | no |
| memory_size | Lambda memory in MB | number | 128 | no |
| log_retention_days | CloudWatch log retention | number | 30 | no |

## Outputs

| Name | Description |
|------|-------------|
| lambda_function_arn | ARN of the Lambda function |
| lambda_function_name | Name of the Lambda function |
| lambda_role_arn | ARN of the Lambda IAM role |
