# Terraform Guidance

The purpose of this repo is to provide guidance on terraform patterns and also serve as a landing space for generic, sharable modules.

## Setup and Topology

How a project is organized can have a large impact on maintainability as the project grows and updates are necessary. [Read More...](topology.md)

## Reusable Modules

Terraform modules in this repository are designed to be generic and helpful to the majority case of apps.
They can be included in your Terraform code like this (_kms_secrets_ for example):

```terraform
module "secrets" {
  source = "github.com/RSS-Engineering/terraform.git?ref={commit}/modules/kms_secrets"
  
  context = {
    environment = "dev"
  }
  
  secrets = [{
    key        = "password"
    kms_key_id = "mrk-1234567890098765432"
    ciphertext = "aHVudGVyMg=="
  }]
}
```

Terraform good practice is to specify a commit hash when sourcing an external module to prevent module changes from unexpectly breaking your deployment pipeline.

### kms_secrets

[kms_secrets](modules/kms_secrets.md) allows you to store multiple secrets in your repository in encrypted form. This provides secrets that terraform can use without needing them to be stored and managed in a separate secure store such as PasswordSafe, SecretsManager or as an SSM Param.
