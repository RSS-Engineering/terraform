### kms_secrets

_kms_secrets_ allows you to store multiple secrets in your repository in encrypted form. This provides secrets that terraform can use without needing them to be stored and managed in a separate secure store such as PasswordSafe, SecretsManager or as an SSM Param. Example:

```terraform
module "secrets" {
  source = "github.com/RSS-Engineering/terraform.git?ref={commit}/modules/kms_secrets"

  context = {
    environment = "dev"
  }

  secrets = [{
    key        = "rds_password"
    kms_key_id = var.rds_password_kms_key_id
    ciphertext = var.rds_password_ciphertext
  }]

  tags = var.tags
}
```

You can then reference the secrets like:
```
module.secrets.plaintext["rds_password"]
```

#### Encrypting secrets prior to use

Because secrets are stored in ciphertext in your project repository, you must provide that ciphertext to _kms_secrets_. To encrypt your secrets:

1. Create a customer-managed key in the AWS KMS Console. Note the KMS KeyId.

*Note: This KMS Key will exist outside of your current infrastructure repository. This is a chicken-and-egg problem.*

2. Write your desired secret in a plaintext file locally:
```bash
echo -n 'master-password' > plaintext-password
```

3. Use AWS CLI to encrypt your secret:
```bash
aws kms encrypt --key-id {KeyId from step 1} --plaintext fileb://plaintext-password --encryption-context environment=dev --output text --query CiphertextBlob
```
*Note: The _encryption-context_ provided here must match the _context_ property provided to kms_secrets*

4. Provide output as ciphertext to _kms_secrets_ for that secret _key_ and _kms_key_id_
