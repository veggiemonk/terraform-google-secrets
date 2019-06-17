
output "key_ring_id" {
  value = google_kms_key_ring.ring.id
}

output "crypto_key_id" {
  value = google_kms_crypto_key.key.id
}
