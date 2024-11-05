output "db_address" {
  value = aws_db_instance.gym-track-core.address
}

output "db_username" {
  value     = aws_db_instance.gym-track-core.username
  sensitive = true
}

output "db_password" {
  value     = aws_db_instance.gym-track-core.password
  sensitive = true
}
