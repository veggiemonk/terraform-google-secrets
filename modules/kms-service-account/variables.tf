variable "region" {
  type    = "string"
  default = "europe-west1"
}

variable "project_id" {

}


variable "kms_key_ring_prefix" {
  type    = "string"
  default = "vault-"

  description = <<EOF
String value to prefix the generated key ring with.
EOF
}

variable "kms_key_ring" {
  type    = "string"
  default = ""

  description = <<EOF
String value to use for the name of the KMS key ring. This exists for
backwards-compatability for users of the existing configurations. Please use
kms_key_ring_prefix instead.
EOF
}

variable "kms_crypto_key" {
  type    = "string"
  default = "vault-init"

  description = <<EOF
String value to use for the name of the KMS crypto key.
EOF
}


variable "key_rotation_period" {
  default = "604800s"
}


variable "kms_role" {
  default = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
}


variable "service_account_email" {

}
