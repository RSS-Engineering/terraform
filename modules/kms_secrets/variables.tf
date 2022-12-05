variable "tags" {
  type = map(string)

  default = {}
}

variable "secretsmanager_key" {
  type        = string
  description = "Provide a key to store secrets in secrets manager"

  default = ""
}

# To generate a new ciphertext, refer to the method used here:
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/kms_secrets
# `kms_key_id` is only to verify the existence of the key used to encrypt the ciphertext.
variable "secrets" {
  type = list(object({
    key        = string
    kms_key_id = string
    ciphertext = string
  }))

  description = "List of secrets containing key (secret label), kms_key_id, and the ciphertext encrypted with that key."
}

variable "description" {
  type        = string
  description = "Add something meaningful to help your future self understand what this key is used for."

  default = ""
}

variable "context" {
  type = map(string)
}

variable "ssm_parameter_prefix" {
  type        = string
  description = "Provide a parameter prefix to store the secrets in SSM Parameter Store"
  default     = ""
}

variable "use_custom_kms_key_for_ssm" {
  type        = bool
  description = "Use the default AWS managed KMS key to encrypt the secrets in SSM Parameter Store"
  default     = false
}
