###############################################################################
## Project                                                                   ##
###############################################################################
resource "google_project" "demo" {
  name       = "Demo Project"
  project_id =  "${var.env_name}-${random_id.role_id.hex}"
  billing_account = var.billing_account
}

# Use `gcloud` to enable:
# - serviceusage.googleapis.com
# - cloudresourcemanager.googleapis.com
resource "null_resource" "enable_service_usage_api" {
  provisioner "local-exec" {
    command = "gcloud services enable serviceusage.googleapis.com cloudresourcemanager.googleapis.com --project ${google_project.demo.project_id}"
  }

  depends_on = [google_project.demo]
}

# Wait for the new configuration to propagate
# (might be redundant)
resource "time_sleep" "wait_project_init" {
  create_duration = "60s"

  depends_on = [null_resource.enable_service_usage_api]
}

# Enable services in newly created GCP Project.
resource "google_project_service" "gcp_services" {
  for_each = toset([
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "monitoring.googleapis.com",
    "networkservices.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
    ])

  service = each.key
  disable_dependent_services=true
  project            = google_project.demo.project_id
  depends_on = [time_sleep.wait_project_init]
}

###############################################################################
## VPC and Subnets                                                           ##
###############################################################################


resource "google_compute_network" "vpc_network" {
  name                    = "${var.env_name}-vpc-network"
  project                 = google_project.demo.project_id
  auto_create_subnetworks = true
  depends_on = [google_project_service.gcp_services]
}

###############################################################################
## MongoDB Instance                                                          ##
###############################################################################


resource "google_compute_instance" "mongodb" {
  name         = "mongodb"
  zone         = "us-east1-c"
  machine_type = "e2-micro"
  project      = google_project.demo.project_id

  metadata_startup_script = file("${path.module}/mongodb-user_data.sh")

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }
  // Override fields from machine image
  can_ip_forward = false

  network_interface {
    network = "default"

    access_config {
      network_tier = "STANDARD"
    }
  }
  
  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.mongodb.email
    scopes = ["cloud-platform"]
  }
  depends_on = [google_project_service.gcp_services]
}

###############################################################################
## Excessive IAM role for MongoDB instance                                   ##
###############################################################################

# Make sure role has a unique name.
resource "random_id" "role_id" {
  byte_length = 8
}

resource "google_service_account" "mongodb" {
  project      = google_project.demo.project_id
  account_id   = "mongodb-${random_id.role_id.hex}"
  display_name = "MongoDB Service Account"
  depends_on = [google_project_service.gcp_services]
}

resource "google_project_iam_binding" "mongodb" {
  project = google_project.demo.project_id
  role    = "roles/compute.admin"
  members = [
    "serviceAccount:${google_service_account.mongodb.email}"
  ]
  depends_on = [google_project_service.gcp_services]
}

###############################################################################
## Publicly accessible S3 bucket                                             ##
###############################################################################

resource "google_storage_bucket" "mongodb-backup" {
  name          = "${var.env_name}-mongodb-backup-${random_id.role_id.hex}"
  project       = google_project.demo.project_id
  location      = "US"
  force_destroy = true
  depends_on = [google_project_service.gcp_services]
}

resource "google_storage_bucket_access_control" "public_rule" {
  bucket = google_storage_bucket.mongodb-backup.id
  role   = "READER"
  entity = "allUsers"
  depends_on = [google_storage_bucket.mongodb-backup]
}

###############################################################################
## Security Groups                                                           ##
###############################################################################


###############################################################################
## GKE Cluster                                                               ##
###############################################################################

resource "google_container_cluster" "demo" {
  name       = "${var.env_name}-gke-${random_id.role_id.hex}"
  location = var.region
  project    = google_project.demo.project_id

  network    = google_compute_network.vpc_network.name
 
# Enabling Autopilot for this cluster
  enable_autopilot = true
  depends_on = [google_project_service.gcp_services]
}

data "google_client_config" "demo" {
}

resource "kubernetes_cluster_role_binding" "permissive_binding" {
  metadata {
    name = "permissive-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "User"
    name      = "admin"
    api_group = "rbac.authorization.k8s.io"
  }
  subject {
    kind      = "User"
    name      = "kubelet"
    api_group = "rbac.authorization.k8s.io"
  }
  subject {
    kind      = "Group"
    name      = "system:serviceaccounts"
    api_group = "rbac.authorization.k8s.io"
  }
  depends_on = [google_container_cluster.demo]
}

###############################################################################
## Jenkins Helm release                                                      ##
###############################################################################

resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  version    = "4.2.12"

  values = [
    "${file("${path.module}/jenkins-values.yaml")}"
  ]

  depends_on = [google_container_cluster.demo]
}

## Budget Notifications


resource "null_resource" "enable_budgets" {
  provisioner "local-exec" {
    command = "gcloud billing budgets create --billing-account=${var.billing_account} --display-name=${var.budget_name} --budget-amount=${var.budget_amount}${var.budget_currency} --threshold-rule=percent=0.80 --threshold-rule=percent=1.0,basis=forecasted-spend"
  }
}

resource "google_monitoring_notification_channel" "notification_channel" {
  display_name = var.budget_name
  type         = "email"
  project      = google_project.demo.project_id

  labels = {
    email_address = var.budget_email
 }
  depends_on = [null_resource.enable_budgets]
}