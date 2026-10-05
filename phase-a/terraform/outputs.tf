output "pool_name" {
  description = "Team Pool name the worker joins, and the cursor-pool security group tag."
  value       = var.pool_name
}

output "network_mode" {
  description = "public_lab or private_nat."
  value       = var.network_mode
}

output "instance_id" {
  description = "EC2 instance id of the Phase A worker."
  value       = aws_instance.worker.id
}

output "security_group_id" {
  description = "Worker security group. Tagged cursor-pool=<pool_name>."
  value       = aws_security_group.worker.id
}

output "secret_arn" {
  description = "Secrets Manager ARN. The secret has no value until put-secret-value."
  value       = aws_secretsmanager_secret.service_account_key.arn
}

output "secret_name" {
  description = "Secrets Manager name."
  value       = aws_secretsmanager_secret.service_account_key.name
}

output "cursor_egress_cidrs" {
  description = "IPv4 /32 CIDRs allowed to Cursor hosts, resolved at apply time."
  value       = [for ip in sort(tolist(local.cursor_ipv4)) : "${ip}/32"]
}

output "put_secret_value_command" {
  description = "Run after apply. The key file stays on your machine and out of git, tfvars, and state."
  value       = "aws secretsmanager put-secret-value --region ${var.aws_region} --secret-id ${aws_secretsmanager_secret.service_account_key.arn} --secret-string file://service-account-key.txt"
}
