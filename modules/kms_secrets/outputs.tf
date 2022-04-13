output "plaintext" {
  value = local.secrets_map

  sensitive = true
}

output "context" {
  value = var.context
}

output "secrets" {
  value = var.secrets
}

output "secretsmanager_key" {
  value = var.secretsmanager_key
}

output "tags" {
  value = var.tags
}
