provider "google" {
}

provider "kubernetes" {
  host                   = google_container_cluster.demo.endpoint
  token                  = data.google_client_config.demo.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.demo.master_auth.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
  host                   = google_container_cluster.demo.endpoint
  token                  = data.google_client_config.demo.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.demo.master_auth.0.cluster_ca_certificate)
 }
}