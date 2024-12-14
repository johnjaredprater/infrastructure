output "db_host" {
  value = digitalocean_database_cluster.gym-track-core.private_host
}

output "db_port" {
  value = digitalocean_database_cluster.gym-track-core.port
}

output "db_uri" {
  value     = digitalocean_database_cluster.gym-track-core.private_uri
  sensitive = true
}

output "db_username" {
  value     = digitalocean_database_cluster.gym-track-core.user
  sensitive = true
}

output "db_password" {
  value     = digitalocean_database_cluster.gym-track-core.password
  sensitive = true
}
