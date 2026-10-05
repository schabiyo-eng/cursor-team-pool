variable "aws_region" {
  description = "AWS region for the worker, secret, and interface endpoint."
  type        = string
  default     = "us-east-1"
}

variable "pool_name" {
  description = "Cursor Team Pool name. The worker joins this pool. The security group is tagged cursor-pool=<pool_name>. Use a name other than default so the pool is an any-repo named pool."
  type        = string
  default     = "lab"

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_-]{0,31}$", var.pool_name)) && var.pool_name != "default"
    error_message = "pool_name must be 1-32 characters of letters, digits, hyphens, or underscores, start with a letter or digit, and must not be \"default\"."
  }
}

variable "network_mode" {
  description = "private_nat (recommended enterprise default) places the worker in a new private subnet and sends egress through a NAT gateway in that VPC. public_lab is the cheap throwaway lab option: the worker sits in a public subnet with a public IP."
  type        = string
  default     = "private_nat"

  validation {
    condition     = contains(["public_lab", "private_nat"], var.network_mode)
    error_message = "network_mode must be public_lab or private_nat."
  }
}

variable "vpc_id" {
  description = "VPC for the worker. Null uses the region's default VPC."
  type        = string
  default     = null
  nullable    = true
}

variable "public_subnet_id" {
  description = "Public subnet for a public_lab worker, or for the NAT gateway in private_nat mode. Null uses the first public subnet in the VPC."
  type        = string
  default     = null
  nullable    = true
}

variable "private_subnet_cidr" {
  description = "CIDR for the private worker subnet when network_mode is private_nat. Null derives a /24 near the top of the VPC CIDR."
  type        = string
  default     = null
  nullable    = true
}

variable "lab_egress" {
  description = "When true, also allow outbound TCP 80 and 443 to 0.0.0.0/0 so the worker can reach git hosts, package registries, and SSM public endpoints. Strict Cursor A-record rules remain either way."
  type        = bool
  default     = false
}

variable "instance_type" {
  description = "EC2 instance type. Match ami_architecture (t3 for x86_64, t4g for arm64)."
  type        = string
  default     = "t3.small"
}

variable "ami_architecture" {
  description = "Amazon Linux 2023 architecture."
  type        = string
  default     = "x86_64"

  validation {
    condition     = contains(["x86_64", "arm64"], var.ami_architecture)
    error_message = "ami_architecture must be x86_64 or arm64."
  }
}

variable "root_volume_size_gb" {
  description = "Encrypted gp3 root volume size in GiB."
  type        = number
  default     = 30
}

variable "idle_release_timeout_seconds" {
  description = "Passed to agent worker --idle-release-timeout. The worker leaves the pool after this many idle seconds."
  type        = number
  default     = 600
}

variable "secret_name" {
  description = "Secrets Manager name for the empty service-account-key container. The key value is never a Terraform input."
  type        = string
  default     = null
  nullable    = true
}

variable "secret_recovery_window_in_days" {
  description = "Secrets Manager recovery window. 0 lets terraform destroy delete the lab secret immediately. Use 7 or more outside a lab."
  type        = number
  default     = 0

  validation {
    condition     = var.secret_recovery_window_in_days == 0 || (var.secret_recovery_window_in_days >= 7 && var.secret_recovery_window_in_days <= 30)
    error_message = "secret_recovery_window_in_days must be 0 or between 7 and 30."
  }
}

variable "cursor_hosts" {
  description = "Hosts whose A records are snapshotted at apply time and allowed on TCP 443. Includes the CLI install host, the agent session hosts, and the artifact bucket."
  type        = list(string)
  default = [
    "cursor.com",
    "downloads.cursor.com",
    "api2.cursor.sh",
    "api2direct.cursor.sh",
    "cloud-agent-artifacts.s3.us-east-1.amazonaws.com",
  ]
}
