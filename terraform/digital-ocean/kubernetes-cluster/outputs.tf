output "project_id" {
  value = var.project_id
}

output "cluster_endpoint" {
  value = digitalocean_kubernetes_cluster.gym_track_prod.endpoint
}

output "region" {
  value = var.region
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = digitalocean_kubernetes_cluster.gym_track_prod.name
}

output "cluster_id" {
  value = digitalocean_kubernetes_cluster.gym_track_prod.id
}

output "vpc_id" {
  value = digitalocean_vpc.gym_track.id
}
