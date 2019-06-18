terraform {
  # This module has been updated with 0.12 syntax, which means it is no longer compatible with any versions below 0.12.
  required_version = ">= 0.12"
}

#------------------------------------------------------------------------------
# KMS
#------------------------------------------------------------------------------

# Generate a random suffix for the KMS keyring. Like projects, key rings names
# must be globally unique within the project. A key ring also cannot be
# destroyed, so deleting and re-creating a key ring will fail.
#
# This uses a random_id to prevent that from happening.
resource "random_id" "kms_random" {
  prefix      = var.kms_key_ring_prefix
  byte_length = "8"
}

# Obtain the key ring ID or use a randomly generated on.
locals {
  kms_key_ring = var.kms_key_ring != "" ? var.kms_key_ring : random_id.kms_random.hex
}

# Create the KMS key ring
resource "google_kms_key_ring" "ring" {
  name     = local.kms_key_ring
  location = var.region
  project  = var.project_id
}

# Create the crypto key for encrypting 
resource "google_kms_crypto_key" "key" {
  name            = var.kms_crypto_key
  key_ring        = google_kms_key_ring.ring.id
  rotation_period = var.key_rotation_period


  lifecycle {
    #
    # CryptoKeys cannot be deleted from Google Cloud Platform. 
    # Destroying a Terraform-managed CryptoKey will remove it 
    # from state and delete all CryptoKeyVersions, rendering the key unusable, 
    # but will not delete the resource on the server. 
    # When Terraform destroys these keys, 
    # any data previously encrypted with these keys will be irrecoverable!!! 
    # Hence, let's prevent terraform from destroying those keys
    prevent_destroy = true
  }
}

#------------------------------------------------------------------------------
# SERVICE ACCOUNT
#------------------------------------------------------------------------------

# Grant service account access to the key
resource "google_kms_crypto_key_iam_member" "iam" {
  crypto_key_id = google_kms_crypto_key.key.id
  role          = var.kms_role
  member        = "serviceAccount:${var.service_account_email}"
}

