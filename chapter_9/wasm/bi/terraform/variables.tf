variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Prefix for named AWS resources."
  type        = string
  default     = "ducklake-guide-wasm"
}

variable "vpc_id" {
  description = "VPC that contains the target subnet."
  type        = string
}

variable "subnet_id" {
  description = "Public subnet for the EC2 instance and Elastic IP."
  type        = string
}

variable "key_pair_name" {
  description = "Name for the Terraform-managed EC2 key pair."
  type        = string
  default     = "ducklake-guide-wasm"
}

variable "public_key_path" {
  description = "Path to the local SSH public key Terraform registers as the EC2 key pair."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks permitted to SSH and connect to Quack, for example [\"203.0.113.25/32\"]."
  type        = list(string)
}

variable "ducklake_bucket_name" {
  description = "Name of an EXISTING S3 bucket to store DuckLake Parquet data in. This bucket is not created or destroyed by Terraform -- only read via a data source -- since it is shared with other examples in this book."
  type        = string
}

variable "ducklake_prefix" {
  description = "Key prefix within ducklake_bucket_name reserved for this example's DuckLake data, e.g. \"chapter_9/wasm\"."
  type        = string
  default     = "chapter_9/wasm"
}

variable "quack_token" {
  description = "Shared token clients send to the Quack server."
  type        = string
  sensitive   = true
}

variable "instance_type" {
  description = "Small Graviton instance type suitable for this demo."
  type        = string
  default     = "t4g.small"
}

variable "ami_id" {
  description = "Optional ARM64 Ubuntu AMI ID. Null selects the latest Ubuntu 22.04 ARM64 AMI."
  type        = string
  default     = null
  nullable    = true
}

variable "quack_port" {
  description = "TCP port exposed by Quack."
  type        = number
  default     = 9494
}

variable "root_volume_size_gb" {
  description = "Size of the EBS root volume that stores the Quack DuckDB catalog."
  type        = number
  default     = 20
}

variable "delete_root_volume_on_termination" {
  description = "Whether terminating the instance also deletes its EBS root volume."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags applied to AWS resources."
  type        = map(string)
  default     = {}
}
