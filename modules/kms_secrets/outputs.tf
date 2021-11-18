output "plaintext" {
  value = local.secrets_map

  sensitive = true
}
