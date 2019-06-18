# ---------------------------------------------------------------------------------------------------------------------
# PREPARE PROVIDERS
# ---------------------------------------------------------------------------------------------------------------------

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE SERVICE ACCOUNT IN A PROJECT
# ---------------------------------------------------------------------------------------------------------------------
module "project" {
  source = "../../../terraform-google-project/modules/gcp-project-service-account"
  //  source = "github.com/veggiemonk/terraform-google-project//modules/gcp-project-service-account"

  project_id                = var.project_id
  service_account_name      = "${var.name_prefix} Server"
  service_account_id        = "${var.name_prefix}-server"
  service_account_iam_roles = var.service_account_iam_roles
}

# Use a random suffix to prevent overlap in network names
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE NETWORK
# ---------------------------------------------------------------------------------------------------------------------
module "network" {
  source = "github.com/gruntwork-io/terraform-google-network//modules/vpc-network"

  name_prefix = "${var.cluster_name}-network-${random_string.suffix.result}"
  project     = module.project.project_id
  region      = var.region


  cidr_block           = var.vpc_cidr_block
  secondary_cidr_block = var.vpc_secondary_cidr_block
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE BUCKET STORAGE TO USE AS A BACKEND
# ---------------------------------------------------------------------------------------------------------------------
module "storage" {
  source                = "github.com/veggiemonk/terraform-google-bucket//modules/storage-versioned-service-account"
  project_id            = module.project.project_id
  service_account_email = module.project.service_account_email

  bucket_prefix = var.name_prefix
  location      = var.storage_location
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE ENCRYPTION KEY
# ---------------------------------------------------------------------------------------------------------------------
module "encryption" {
  source = "../../modules/kms-service-account"

  project_id            = module.project.project_id
  service_account_email = module.project.service_account_email

  region              = var.cluster_location
  kms_key_ring_prefix = var.name_prefix
  kms_crypto_key      = "${var.name_prefix}-init"
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A BASTION HOST TO ACCESS THE CLUSTER
# ---------------------------------------------------------------------------------------------------------------------
module "bastion" {
  source = "github.com/gruntwork-io/terraform-google-network//modules/bastion-host"

  zone       = var.bastion_zone
  project    = module.project.project_id
  subnetwork = module.network.public_subnetwork

  instance_name = "${var.name_prefix}-bastion"
  source_image  = "debian-cloud/debian-9"
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A PRIVATE GKE CLUSTER
# ---------------------------------------------------------------------------------------------------------------------
module "k8s" {
  source = "github.com/gruntwork-io/terraform-google-gke//modules/gke-cluster"

  name     = var.cluster_name
  location = var.cluster_location
  project  = module.project.project_id

  network = module.network.network
  # See the network access tier table for full details:
  # https://github.com/gruntwork-io/terraform-google-network/tree/master/modules/vpc-network#access-tier
  subnetwork = module.network.private_subnetwork


  # When creating a private cluster, the 'master_ipv4_cidr_block' has to be defined and the size must be /28
  master_ipv4_cidr_block = var.master_ipv4_cidr_block

  master_authorized_networks_config = [{
    cidr_blocks = [{
      cidr_block   = "${module.bastion.address}/32"
      display_name = "${var.name_prefix}-bastion-vm"
    }],
  }]

  cluster_secondary_range_name = module.network.public_subnetwork_secondary_range_name


  # This setting will make the cluster private
  enable_private_nodes = "true"

  # To make testing easier, we could keep the public endpoint available (value = false).
  # In production, we highly recommend restricting access to only within the network boundary, (value = true)
  # requiring your users to use a bastion host or VPN.
  disable_public_endpoint = "true"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A NODE POOL
# ---------------------------------------------------------------------------------------------------------------------
resource "google_container_node_pool" "node_pool" {
  provider = "google-beta"

  name     = "private-pool"
  project  = var.project_id
  location = var.cluster_location
  cluster  = module.k8s.name

  initial_node_count = "1"

  autoscaling {
    min_node_count = "1"
    max_node_count = "5"
  }

  management {
    auto_repair  = "true"
    auto_upgrade = "true"
  }

  node_config {
    image_type   = "COS"
    machine_type = "n1-standard-1"

    labels = {
      private-pools-example = "true"
    }

    # Add a private tag to the instances. See the network access tier table for full details:
    # https://github.com/gruntwork-io/terraform-google-network/tree/master/modules/vpc-network#access-tier
    tags = [
      module.network.private,
      "private-pool-example",
    ]

    disk_size_gb = "30"
    disk_type    = "pd-standard"
    preemptible  = false

    service_account = "${module.project.service_account_email}"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  lifecycle {
    ignore_changes = ["initial_node_count"]
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

# Provision IP
resource "google_compute_address" "vault" {
  name    = "vault-lb"
  region  = "${var.region}"
  project = "${module.project.project_id}"

  depends_on = [module.project]
}

# ---------------------------------------------------------------------------------------------------------------------
# GENERATE SELF SIGNED TLS CERTIFICATE
# ---------------------------------------------------------------------------------------------------------------------

# Generate self-signed TLS certificates. Unlike @kelseyhightower's original
# demo, this does not use cfssl and uses Terraform's internals instead.
resource "tls_private_key" "vault-ca" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "tls_self_signed_cert" "vault-ca" {
  key_algorithm   = "${tls_private_key.vault-ca.algorithm}"
  private_key_pem = "${tls_private_key.vault-ca.private_key_pem}"

  subject {
    common_name  = "vault-ca.local"
    organization = "HashiCorp Vault"
  }

  validity_period_hours = 8760
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "digital_signature",
    "key_encipherment",
  ]

  provisioner "local-exec" {
    command = "echo '${self.cert_pem}' > tls/ca.pem && chmod 0600 tls/ca.pem"
  }
}

# Create the Vault server certificates
resource "tls_private_key" "vault" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

# Create the request to sign the cert with our CA
resource "tls_cert_request" "vault" {
  key_algorithm   = "${tls_private_key.vault.algorithm}"
  private_key_pem = "${tls_private_key.vault.private_key_pem}"

  dns_names = [
    "vault",
    "vault.local",
    "vault.default.svc.cluster.local",
  ]

  ip_addresses = [
    "${google_compute_address.vault.address}",
  ]

  subject {
    common_name  = "vault.local"
    organization = "HashiCorp Vault"
  }
}

# Now sign the cert
resource "tls_locally_signed_cert" "vault" {
  cert_request_pem = "${tls_cert_request.vault.cert_request_pem}"

  ca_key_algorithm   = "${tls_private_key.vault-ca.algorithm}"
  ca_private_key_pem = "${tls_private_key.vault-ca.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.vault-ca.cert_pem}"

  validity_period_hours = 8760

  allowed_uses = [
    "cert_signing",
    "client_auth",
    "digital_signature",
    "key_encipherment",
    "server_auth",
  ]

  provisioner "local-exec" {
    command = "echo '${self.cert_pem}' > tls/vault.pem && echo '${tls_self_signed_cert.vault-ca.cert_pem}' >> tls/vault.pem && chmod 0600 tls/vault.pem"
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY VAULT ON TOP OF KUBERNETES
# ---------------------------------------------------------------------------------------------------------------------

# Query the client configuration for our current service account, which shoudl
# have permission to talk to the GKE cluster since it created it.
data "google_client_config" "current" {}

# This file contains all the interactions with Kubernetes
provider "kubernetes" {
  load_config_file = false
  host             = "${module.k8s.endpoint}"

  cluster_ca_certificate = "${base64decode(module.k8s.cluster_ca_certificate)}"
  token                  = "${data.google_client_config.current.access_token}"
}

# Write the secret
resource "kubernetes_secret" "vault-tls" {
  metadata {
    name = "vault-tls"
  }

  data = {
    "vault.crt" = "${tls_locally_signed_cert.vault.cert_pem}\n${tls_self_signed_cert.vault-ca.cert_pem}"
    "vault.key" = tls_private_key.vault.private_key_pem
    "ca.crt"    = tls_self_signed_cert.vault-ca.cert_pem
  }
}

# Render the YAML file

data "template_file" "vault" {
  template = file("${path.module}/vault.yaml")

  vars = {
    load_balancer_ip         = google_compute_address.vault.address
    num_vault_pods           = var.num_vault_pods
    vault_container          = var.vault_container
    vault_init_container     = var.vault_init_container
    vault_recovery_shares    = var.vault_recovery_shares
    vault_recovery_threshold = var.vault_recovery_threshold

    project = module.encryption.key_ring_project

    kms_region     = module.encryption.key_ring_region
    kms_key_ring   = module.encryption.key_ring_name
    kms_crypto_key = module.encryption.crypto_key_name

    gcs_bucket_name = module.storage.bucket_name
  }
}

# Submit the job - Terraform doesn't yet support StatefulSets, so we have to
# shell out.
resource "null_resource" "apply" {
  triggers = {
    host                   = md5(module.k8s.endpoint)
    client_certificate     = md5(module.k8s.client_certificate)
    client_key             = md5(module.k8s.client_key)
    cluster_ca_certificate = md5(module.k8s.cluster_ca_certificate)
  }

  depends_on = [
    "kubernetes_secret.vault-tls",
  ]

  provisioner "local-exec" {
    command = <<EOF
gcloud container clusters get-credentials "${module.k8s.name}" --region="${var.region}" --project="${module.project.project_id}"

CONTEXT="gke_${module.project.project_id}_${var.region}_${module.k8s.name}"
echo '${data.template_file.vault.rendered}' | kubectl apply --context="$CONTEXT" -f -
EOF
  }
}

# Wait for all the servers to be ready
resource "null_resource" "wait-for-finish" {
  provisioner "local-exec" {
    command = <<EOF
for i in $(seq -s " " 1 15); do
  sleep $i
  if [ $(kubectl get pod | grep vault | wc -l) -eq ${var.num_vault_pods} ]; then
    exit 0
  fi
done

echo "Pods are not ready after 2m"
exit 1
EOF
  }

  depends_on = ["null_resource.apply"]
}

# Build the URL for the keys on GCS
data "google_storage_object_signed_url" "keys" {
  bucket = module.storage.bucket_name
  path   = "root-token.enc"

  credentials = base64decode(module.project.service_account_private_key)

  depends_on = ["null_resource.wait-for-finish"]
}

# Download the encrypted recovery unseal keys and initial root token from GCS
data "http" "keys" {
  url = data.google_storage_object_signed_url.keys.signed_url
}

# Decrypt the values
data "google_kms_secret" "keys" {
  crypto_key = module.encryption.crypto_key_id
  ciphertext = data.http.keys.body
}
