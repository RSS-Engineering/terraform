# Recommended Infrastructure Topology

The recommendations in this repository assume a multiple-account structure where each project/environment has its own provider (AWS) account. In some cases, there may be a master account to hold common resources but projects should try to keep resources as separate as possible for security and asset-management reasons. ([RAX.IO talk](https://web.microsoftstream.com/video/10e4abe9-fcf6-4a01-b1b7-6f4919a0a28b?channelId=3237e715-5c23-4833-a0a5-1690a7437c3a)) ([further reading](https://www.terraform.io/docs/cloud/guides/recommended-practices/part2.html))

## Project Repository Structure

To achieve code-reuse and environment segregation, place your terraform code in a sub-directory called _infrastructure_ with a structure like:

```
- infrastructure
  - env
    - staging
      - conf.tf
      - main.tf
    - production
      - conf.tf
      - main.tf
  - modules
    - [project-specific modules]
  - main.tf
  - variables.tf

```

The root of each environment will be `infrastructure/env/{environment}/` which will hold environment-specific values. `infrastructure/main.tf` represents the common entry-point for all environments and should be referenced as a module in each environment root.

## Invocation

Terraform can be invoked either within `infrastructure/env/{environment}/` or from the project root like
```shell
terraform -chdir=infrastructure/env/{environment}/ init
```
 The latter is recommended to maintain consistent paths but consistency is most important.

When creating scripts for your NodeJS project, three scripts are recommended. One each for _init_, _plan_, and _apply_.

## Remote State

Terraform needs to store the current state of each environment in a place where it can be shared among developers. The recommended configuration is an S3 bucket and a simple DynamoDB table for locking. For more information about how to set this up refer to https://www.terraform.io/docs/language/settings/backends/s3.html

### Setting up Remote State

Move the [sample-file](https://github.com/RSS-Engineering/terraform/blob/main/backend_state_init/backend.tf.sample) to terraform file and then remove the sample file. 
```bash
mv backend_state_init/backend.tf.sample backend_state_init/backend.tf
```

Now change the metadata `global_tags` inside the  `backend.tf` file and modified the values according to requirement:-
- APPID
- REPO
- ENVIRONMENT
- APPLICATION

Sample config:-
```hcl
locals {
  # https://one.rackspace.com/pages/viewpage.action?pageId=532306599
  # Modified the values according to need and standards
  global_tags = {
    Terraform       = "managed"
    application     = "tf-state-store",
    environment     = "test",
    confidentiality = "Rackspace Public",
    tag-std         = "v1.0",
    appid-or-sso    = "puni9869",
    iac-repository  = "https://github.com/RSS-Engineering/terraform"
  }
}
```

 
```bash
cd backend_state_init/
# Execute the terraform script for setting backend states in s3 and dynamo db.
terraform init
terraform plan
terraform apply
```

Remove the folder `backend_state_init/` once done setting backend state configurations.
