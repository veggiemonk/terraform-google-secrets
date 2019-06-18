# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "region" {
  default = "europe-west1"
}

variable "project_id" {
  default = "vault-dev-242607"
}

variable "name_prefix" {
  default = "vault"
}

variable "storage_location" {
  default = "EU"
}

variable "cluster_location" {
  default = "europe-west1"
}

variable "bastion_zone" {
  default = "europe-west1-b"
}

variable "service_account_iam_roles" {
  type = "list"

  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
  ]
}

variable "services" {
default = [
  "cloudresourcemanager.googleapis.com", # Cloud Resource Manager API
  "cloudshell.googleapis.com", # Cloud Shell API
  "compute.googleapis.com", # Compute Engine API
  "container.googleapis.com", # Kubernetes Engine API
  "containerregistry.googleapis.com", # Container Registry API
  "iam.googleapis.com", # Identity and Access Management (IAM) API
  "cloudkms.googleapis.com", # Cloud Key Management Service (KMS) API
  "logging.googleapis.com", # Stackdriver Logging API
  "oslogin.googleapis.com", # Cloud OS Login API
  "replicapool.googleapis.com", # Compute Engine Instance Group Manager API
  "replicapoolupdater.googleapis.com", # Compute Engine Instance Group Updater API
  "resourceviews.googleapis.com", # Compute Engine Instance Groups API
  "storage-api.googleapis.com", # Google Cloud Storage JSON API
  "storage-component.googleapis.com", # Cloud Storage
]
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "cluster_name" {
  description = "The name of the Kubernetes cluster."
  default     = "vault-cluster"

}

variable "master_ipv4_cidr_block" {
  description = "The IP range in CIDR notation (size must be /28) to use for the hosted master network. This range will be used for assigning internal IP addresses to the master or set of masters, as well as the ILB VIP. This range must not overlap with any other ranges in use within the cluster's network."
  default     = "10.5.0.0/28"
}

# For the example, we recommend a /16 network for the VPC. Note that when changing the size of the network,
# you will have to adjust the 'cidr_subnetwork_width_delta' in the 'vpc_network' -module accordingly.
variable "vpc_cidr_block" {
  description = "The IP address range of the VPC in CIDR notation. A prefix of /16 is recommended. Do not use a prefix higher than /27."
  default     = "10.3.0.0/16"
}

# For the example, we recommend a /16 network for the secondary range. Note that when changing the size of the network,
# you will have to adjust the 'cidr_subnetwork_width_delta' in the 'vpc_network' -module accordingly.
variable "vpc_secondary_cidr_block" {
  description = "The IP address range of the VPC's secondary address range in CIDR notation. A prefix of /16 is recommended. Do not use a prefix higher than /27."
  default     = "10.4.0.0/16"
}


#
# Kubernetes options
# -----------------------------
variable "kubernetes_nodes_per_zone" {
  default     = 1
  description = "Initial node count"
}
variable "kubernetes_nodes_machine_type" {
  default = "n1-standard-1"
}
variable "min_node_count" {
  default = 1
}
variable "max_node_count" {
  default = 5
}

#
# Vault options
# ------------------------------

variable "num_vault_pods" {
  type    = "string"
  default = "3"

  description = <<EOF
Number of Vault pods to run. Anti-affinity rules spread pods across available
nodes. Please use an odd number for better availability.
EOF
}

variable "vault_container" {
  type = "string"
  default = "vault:1.0.1"

  description = <<EOF
Name of the Vault container image to deploy. This can be specified like
"container:version" or as a full container URL.
EOF
}

variable "vault_init_container" {
  type    = "string"
  default = "sethvargo/vault-init:1.0.0"

  description = <<EOF
Name of the Vault init container image to deploy. This can be specified like
"container:version" or as a full container URL.
EOF
}

variable "vault_recovery_shares" {
  type = "string"
  default = "1"

  description = <<EOF
Number of recovery keys to generate.
EOF
}

variable "vault_recovery_threshold" {
  type    = "string"
  default = "1"

  description = <<EOF
Number of recovery keys required for quorum. This must be less than or equal
to "vault_recovery_keys".
EOF
}
