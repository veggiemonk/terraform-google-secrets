#------------------------------------------------------------------------------
# GOOGLE PROVIDER
#------------------------------------------------------------------------------

provider "google" {
  region  = "${var.region}"
  project = "${var.project_id}"
}

provider "google-beta" {
  region  = "${var.region}"
  project = "${var.project_id}"
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
  prefix      = "${var.kms_key_ring_prefix}"
  byte_length = "8"
}

# Obtain the key ring ID or use a randomly generated on.
locals {
  kms_key_ring = "${var.kms_key_ring != "" ? var.kms_key_ring : random_id.kms_random.hex}"
}

# Create the KMS key ring
resource "google_kms_key_ring" "ring" {
  name     = "${local.kms_key_ring}"
  location = "${var.region}"
  project  = "${var.project_id}"
}

# Create the crypto key for encrypting init keys
resource "google_kms_crypto_key" "key" {
  name            = "${var.kms_crypto_key}"
  key_ring        = "${google_kms_key_ring.ring.id}"
  rotation_period = "${var.key_rotation_period}"
}

# Create a custom IAM role with the most minimal set of permissions for the
# KMS auto-unsealer. Once hashicorp/vault#5999 is merged, this can be replaced
# with the built-in roles/cloudkms.cryptoKeyEncrypterDecrypter role.
# resource "google_project_iam_custom_role" "vault-seal-kms" {
#   project     = "${var.project_id}"
#   role_id     = "kmsEncrypterDecryptorViewer"
#   title       = "KMS Encrypter Decryptor Viewer"
#   description = "KMS crypto key permissions to encrypt, decrypt, and view key data"

#   permissions = [
#     "cloudkms.cryptoKeyVersions.useToEncrypt",
#     "cloudkms.cryptoKeyVersions.useToDecrypt",

#     # This is required until hashicorp/vault#5999 is merged. The auto-unsealer
#     # attempts to read the key, which requires this additional permission.
#     "cloudkms.cryptoKeys.get",
#   ]
# }


#------------------------------------------------------------------------------
# SERVICE ACCOUNT
#------------------------------------------------------------------------------


# Grant service account access to the key
resource "google_kms_crypto_key_iam_member" "iam" {
  crypto_key_id = "${google_kms_crypto_key.key.id}"
  role          = "${var.kms_role}"
  member        = "serviceAccount:${var.service_account_email}"
}
