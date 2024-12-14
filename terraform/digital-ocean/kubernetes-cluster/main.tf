data "digitalocean_kubernetes_versions" "example" {
  version_prefix = "1.31."
}

resource "digitalocean_vpc" "gym_track" {
  name        = "gym-track-vpc"
  region      = var.region
  description = "VPC for Kubernetes and Database"
}

resource "digitalocean_kubernetes_cluster" "gym_track_prod" {
  name   = "gym-track"
  region = var.region

  auto_upgrade = true
  version      = data.digitalocean_kubernetes_versions.example.latest_version

  vpc_uuid = digitalocean_vpc.gym_track.id

  maintenance_policy {
    start_time = "04:00"
    day        = "sunday"
  }

  node_pool {
    name       = "autoscale-worker-pool"
    size       = "s-2vcpu-4gb"
    auto_scale = true
    min_nodes  = 1
    max_nodes  = 2
  }
}

# Links the project with the kubernetes cluster
resource "digitalocean_project_resources" "project_resources" {
  project = var.project_id

  resources = [
    digitalocean_kubernetes_cluster.gym_track_prod.urn,
  ]
}