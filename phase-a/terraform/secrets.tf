# Container only. Do not add an aws_secretsmanager_secret_version.
# A version resource would write the service account key into Terraform state.
resource "aws_secretsmanager_secret" "service_account_key" {
  name                    = local.secret_name
  description             = "Cursor Team Pool service account API key for pool ${var.pool_name}. Set the value with put-secret-value after apply."
  recovery_window_in_days = var.secret_recovery_window_in_days
}
