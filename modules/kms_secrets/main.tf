locals {
  secrets_map = { for i, s in var.secrets : s.key => data.aws_kms_secrets.this.plaintext[i] }
}

# This is only here to verify that the kms keys exist.
data "aws_kms_key" "ciphertext_keys" {
  count = length(var.secrets)

  key_id = var.secrets[count.index].kms_key_id
}

data "aws_kms_secrets" "this" {
  dynamic "secret" {
    for_each = var.secrets

    content {
      name    = secret.key
      payload = secret.value.ciphertext

      context = var.context
    }
  }
}

resource "aws_secretsmanager_secret" "this" {
  count = var.secretsmanager_key == "" ? 0 : 1

  name        = var.secretsmanager_key
  description = var.description
}

resource "aws_secretsmanager_secret_version" "this" {
  count = var.secretsmanager_key == "" ? 0 : 1

  secret_id     = aws_secretsmanager_secret.this[0].id
  secret_string = jsonencode(local.secrets_map)
}

resource "aws_ssm_parameter" "this" {
  count = var.ssm_parameter_prefix == "" ? 0 : length(var.secrets)

  name  = "${var.ssm_parameter_prefix}/${var.secrets[count.index].key}"
  type  = "SecureString"
  value = local.secrets_map[var.secrets[count.index].key]
}
