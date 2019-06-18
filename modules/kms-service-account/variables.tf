variable "region" {
  description = "The region in which to create the key"
}

variable "project_id" {
  description = "The id of the project in which to create the key"
}

variable "service_account_email" {
  description = "The service account to give the ability to encrypt and decrypt data with the key"
}

variable "kms_key_ring_prefix" {
  description = "String value to prefix the generated key ring with. A '-' will automatically be added at the end"
}

variable "kms_crypto_key" {
  description = "String value to use for the name of the KMS crypto key. Example: app-init"
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------
variable "kms_role" {
  description = <<EOF
Defines the role to be assigned to the service account.
It defines the access control of the service account to the kms crypto key generated.
EOF
  default = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
}

variable "kms_key_ring" {
  type = string
  default = ""

  description = <<EOF
String value to use for the name of the KMS key ring.
This exists for backwards-compatability for users of the existing configurations.
Please use kms_key_ring_prefix instead.
EOF
}


variable "key_rotation_period" {
  default = "604800s"

  description = <<EOF
Every time this period passes, generate a new CryptoKeyVersion and 
set it as the primary. The first rotation will take place after 
the specified period. The rotation period has the format of a decimal number 
with up to 9 fractional digits, followed by the letter s (seconds). 
It must be greater than a day (ie, 86400).
EOF
}



