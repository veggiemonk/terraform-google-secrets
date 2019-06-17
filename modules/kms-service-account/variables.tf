variable "region" {
  type    = string
  default = "europe-west1"
}

variable "project_id" {
}

variable "kms_key_ring_prefix" {
  type    = string
  default = "myapp-"

  description = <<EOF
String value to prefix the generated key ring with.
EOF

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

variable "kms_crypto_key" {
type    = string
default = "app-init"

description = <<EOF
String value to use for the name of the KMS crypto key.
EOF

}

variable "key_rotation_period" {
description = <<EOF
Every time this period passes, generate a new CryptoKeyVersion and 
set it as the primary. The first rotation will take place after 
the specified period. The rotation period has the format of a decimal number 
with up to 9 fractional digits, followed by the letter s (seconds). 
It must be greater than a day (ie, 86400).
EOF
  default = "604800s"
}

variable "kms_role" {
  description = <<EOF
Defines the role to be assigned to the service account.
It defines the access control of the service account to the kms crypto key generated.
EOF
  default = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
}

variable "service_account_email" {
}

