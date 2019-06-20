# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These parameters must be supplied when consuming this module.
# ---------------------------------------------------------------------------------------------------------------------

variable "project_id" {
  description = "The ID of the project to create the service account in."
}

variable "service_account_name" {
  description = "Displayed name of the service account. Example: 'App server'"
}

variable "service_account_id" {
  description = "ID of the service account. It must match regexp `^[a-z](?:[-a-z0-9]{4,28}[a-z0-9])$`. Meaning: between 4 to 28 characters, containing numbers, lowercase letters and dashes `-`. Example: 'app-server'"
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "service_account_iam_roles" {
  type = list(string)
  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
  ]

  description = "List of the default IAM roles to attach to the service account on. Those default are sane for a GKE cluster."
}
