
output "key_ring_id" {
  value = google_kms_key_ring.ring.id
}

output "crypto_key_id" {
  value = google_kms_crypto_key.key.id
}

output "key_ring_project" {
  value = google_kms_key_ring.ring.project
}

output "key_ring" {
  value = google_kms_key_ring.ring.self_link
}

output "key_ring_region" {
  value = google_kms_key_ring.ring.location
}

output "key_ring_name" {
  value = google_kms_key_ring.ring.name
}

output "crypto_key_name" {
  value = google_kms_crypto_key.key.name
}
