output "k8s_master_version" {
  value = module.k8s.master_version
}

output "address" {
  value = google_compute_address.vault.address
}
