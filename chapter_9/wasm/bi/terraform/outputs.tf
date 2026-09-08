output "quack_public_ip" {
  description = "Stable Elastic IP for Quack clients."
  value       = aws_eip.quack.public_ip
}

output "quack_uri" {
  description = "Quack URI for direct ATTACH from a native DuckDB client. Quack is plain HTTP; use DISABLE_SSL true (or an SSH tunnel, as this book does) since there is no TLS termination here."
  value       = "quack:${aws_eip.quack.public_ip}:${var.quack_port}"
}

output "ducklake_s3_uri" {
  description = "S3 URI used as this example's DuckLake DATA_PATH."
  value       = "s3://${var.ducklake_bucket_name}/${var.ducklake_prefix}/data/"
}

output "ssh_command" {
  description = "SSH command to reach the instance (adjust the key path if you used a different one)."
  value       = "ssh -i ${var.public_key_path == null ? "~/.ssh/id_ed25519" : replace(var.public_key_path, ".pub", "")} ubuntu@${aws_eip.quack.public_ip}"
}

output "quack_token" {
  description = "Quack authentication token for approved clients."
  value       = var.quack_token
  sensitive   = true
}
