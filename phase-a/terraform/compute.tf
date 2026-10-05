data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-${var.ami_architecture}"
}

resource "aws_instance" "worker" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  subnet_id                   = local.worker_subnet_id
  associate_public_ip_address = local.associate_public_ip
  iam_instance_profile        = aws_iam_instance_profile.worker.name
  vpc_security_group_ids      = [aws_security_group.worker.id]
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/templates/user_data.sh.tpl", {
    aws_region   = var.aws_region
    secret_id    = aws_secretsmanager_secret.service_account_key.arn
    pool_name    = var.pool_name
    idle_timeout = var.idle_release_timeout_seconds
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted   = true
    volume_size = var.root_volume_size_gb
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.pool_name}-worker"
  }

  depends_on = [
    aws_iam_role_policy.worker,
    aws_vpc_endpoint.secretsmanager,
    aws_route_table_association.private,
  ]
}
