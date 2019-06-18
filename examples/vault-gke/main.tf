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


module "project" {
  source = "github.com/veggiemonk/terraform-google-project//modules/gcp-project-service-account"

  project_id                = var.project_id
  service_account_name      = "vault Server"
  service_account_id        = "vault-server"
  service_account_iam_roles = ""
}

# Use a random suffix to prevent overlap in network names
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

module "network" {
  source = "github.com/gruntwork-io/terraform-google-network//modules/vpc-network"

  name_prefix = "${var.cluster_name}-network-${random_string.suffix.result}"
  project     = module.project.project_id
  region      = var.region


  cidr_block           = var.vpc_cidr_block
  secondary_cidr_block = var.vpc_secondary_cidr_block
}

// create bucket
module "storage" {
  source                = "github.com/veggiemonk/terraform-google-bucket//modules/storage-versioned-service-account"
  project_id            = module.project.project_id
  service_account_email = module.project.service_account_email
  bucket_prefix         = var.name_prefix
  location              = var.storage_location

}
// create secret
module "encryption" {
  source = "../../modules/kms-service-account"

  project_id            = module.project.project_id
  service_account_email = module.project.service_account_email
}


# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A BASTION HOST TO ACCESS THE CLUSTER
# ---------------------------------------------------------------------------------------------------------------------
module "bastion" {
  source = "github.com/gruntwork-io/terraform-google-network//modules/bastion-host"

  region     = var.region
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

  # To make testing easier, we keep the public endpoint available.
  # In production, we highly recommend restricting access to only within the network boundary,
  # requiring your users to use a bastion host or VPN.
  disable_public_endpoint = "false"

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

// deploy vault

