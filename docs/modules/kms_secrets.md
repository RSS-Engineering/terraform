# kms_secrets

**kms_secrets** allows you to store multiple secrets in your repository in encrypted form. This provides secrets that Terraform can use whether or not you need them at runtime.

## Example Usage

---

### Password secret available at build-time

```terraform
module "secrets" {
  source = "github.com/RSS-Engineering/terraform.git?ref={commit}/modules/kms_secrets"

  context = {
    environment = "dev"
  }

  secrets = [
    {
      key        = "password"
      kms_key_id = "mrk-1234567890098765432"
      ciphertext = "aHVudGVyMg=="
    }
  ]
}
```

### Password secret available at build-time or run-time in Secrets Manager

Storing secrets in SecretsManager is as easy as providing `secretsmanager_key` that will be used to reference them at run-time.

### Storing secrets in SSM Parameter Store

If you provide the `ssm_parameter_prefix` argument to the module, the secrets will be saved to SSM Parameter Store with the given prefix, using `key` as the name.

## Argument Reference

---

The following arguments are supported:

- `context` - (Optional) A map used to encrypt/decrypt the ciphertext. This must be the same as what is provided to encrypt the secrets.
- `secretsmanager_key` - (Optional) A string value key used to save a hash of the `secrets` in SecretsManager in order to access the secrets after deployment.
- `ssm_parameter_prefix` - (Optional) A string value without trailing hashes representing the prefix under which the secrets should be saved into SSM Parameter Store (the resulting parameter name will be: `<ssm_parameter_prefix>/<key>`)
- `use_custom_kms_key_for_ssm` - (Optional) A boolean value indicating whether to use a custom KMS key for encrypting the secrets in SSM Parameter Store. Default to `false` which means that the AWS managed SSM key for SSM Parameter Store will be used.
- `secrets` - A list of objects each with:

  - `key` - A plaintext string value used to reference this secret.
  - `kms_key_id` - The KMS key id used to encrypt/decrypt this secret.

  > **Note**: This KMS Key must exist apart from this module to avoid a circular-dependency situation. If you choose to manage your KMS keys that you reference here with Terraform, it is highly recommended to set the `prevent_destroy` lifecycle attribute.

  - `ciphertext` - The base64-encoded ciphertext of the secret.

    Each secret must be encrypted at development time with the pre-created customer-managed KMS key that is referenced in `kms_key_id`.

    1. Write your desired secret in a plaintext file locally:

    ```bash
    echo -n 'master-password' > plaintext-password
    ```

    > **Note**: Use this method exactly to avoid a more advanced editor potentially applying a _newline_ at the end of the file.

    2. Use the AWS CLI to encrypt your secret:

    ```bash
    aws kms encrypt --key-id {kms_key_id} --plaintext fileb://plaintext-password --encryption-context environment=dev --output text --query CiphertextBlob
    ```

    > **Note**: The _encryption-context_ provided here must match the _context_ property provided to the kms_secrets module.

    3. The output of the previous step is the value to use for `ciphertext`.

## Attributes Reference

---

In addition to all arguments above, the following attributes are exported:

- `plaintext` - A map of each secret key to its decrypted value for use in other resources attributes. This attribute is marked as _sensitive_ to prevent it from appearing in plaintext in console output.

  Example usage:

  ```terraform
  module.secrets.plaintext["password"]
  ```
