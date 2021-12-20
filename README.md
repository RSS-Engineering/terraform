# Terraform Guidance

The purpose of this repo is to provide guidance on terraform patterns and also serve as a landing space for generic, sharable modules.

## Recommended Infrastructure Topology

The recommendations in this repository assume a multiple-account structure where each project/environment has its own provider (AWS) account. In some cases, there may be a master account to hold common resources but projects should try to keep resources as separate as possible for security and asset-management reasons. ([further reading](https://www.terraform.io/docs/cloud/guides/recommended-practices/part2.html))

### Topology Overview

Terraform needs to store the current state of each environment in a place where it can be shared among developers. The recommended configuration is an S3 bucket and a simple DynamoDB table for locking. For more information about how to set this up refer to https://www.terraform.io/docs/language/settings/backends/s3.html

There is a [sample-file](backend_state_init/backend.tf.sample) that can be used to set this up automatically.

#### Steps:-
Move the sample file to terraform file and then remove the sample file. 
```bash
mv backend_state_init/backend.tf.sample backend_state_init/backend.tf
```
 
```bash
cd backend_state_init/
# Execute the terraform script for setting backend states in s3 and dynamo db.
terraform init
terraform plan
terraform apply
```

Remove the folder `backend_state_init/` once done setting backend state configurations.

### Project Repository Structure

To achieve code-reuse and environment segregation, place your terraform code in a sub-directory called _infrastructure_ with a structure like:

```
- infrastructure
  - env
    - staging
      - conf.tf
      - main.tf
    - prod
      - conf.tf
      - main.tf
  - modules
    - [project-specific modules]
  - main.tf
  - variables.tf

```

The root of each environment will be `infrastructure/env/{environment}/` which will hold environment-specific values. `infrastructure/main.tf` represents the common entry-point for all environments and should be referenced as a module in each environment root.

Terraform can be invoked either within `infrastructure/env/{environment}/` or from the project root like `terraform -chdir=infrastructure/env/{environment}/ init`. The latter is recommended to maintain consistent paths but consistency is most important.

## Modules

Terraform modules in this repository can be referenced like (_kms_secrets_ for example):

```terraform
module "secrets" {
  source = "github.com/RSS-Engineering/terraform.git?ref={commit}/modules/kms_secrets"

  ...
}
```

You should always specify a commit hash to prevent changes in this repository from potentially affecting your project.

### kms_secrets

[kms_secrets](./modules/kms_secrets/) allows you to store multiple secrets in your repository in encrypted form. This provides secrets that terraform can use without needing them to be stored and managed in a separate secure store such as PasswordSafe, SecretsManager or as an SSM Param.
