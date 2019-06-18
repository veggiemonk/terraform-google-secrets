output "k8s_master_version" {
  value = module.k8s.master_version
}

# Output the initial root token
output "root_token" {
  sensitive = true
  value     = data.google_kms_secret.keys.plaintext
}

output "address" {
  value = google_compute_address.vault.address
}