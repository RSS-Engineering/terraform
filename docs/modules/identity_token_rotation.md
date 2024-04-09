# identity_token_rotation

This module will create:
 1) Lambda and
 2) Secret (With auto rotation enabled)
 
* Lambda will make a call to internal identity api and generate a token. Then update it to the secret (Created by this module).
  Username/password (used to make the internal identiy call) should be stored in a secret string with json body like:
  {
    username = user1
    password = pass1
  }
* Secret: Auto rotation enabled on this secret with a scheduled cron expression. So auto rotation will invoke the above lambda on scheduled cron expression.

## Example Usage

---

```terraform
module token_rotation {
    source                     = "github-path"
    resource_prefix            = "test-${local.environment}-${terraform.workspace}"
    resource_path              = "test/${local.environment}/${terraform.workspace}"
    lambda_runtime             = "python3.8"
    private_subnet_ids         = [172.16.1.0/24]
    security_group_ids         = [sg-903004f8]
    service_account_secret_arn = aws_secretsmanager_secret_version.service_account.arn
    rotation_schedule_expression = "rate(6 hours)"
}

```

## Argument Reference

---

The following arguments are supported:

* `lambda_runtime` - Python runtime
* `private_subnet_ids` - List of private subnet ids to launch the lambda.
* `security_group_ids` - List of private security group ids to launch the lambda.
* `service_account_secret_arn` - Secret where username/password for internal-identiy-api call are stored.
* `use_janus_proxy` - Boolean - Use proxy endpoint or direct internal api endpoint
* `rotation_schedule_expression` - Schedule time to invoke the token rotation.
* `resource_prefix` - Prefix used for resources (Lambda/layer).
* `resource_path` - Prefixed path for secret toke. ex: ${var.resource_path}/service-account/token"
