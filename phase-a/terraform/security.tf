# Inline egress so Terraform drops the VPC default allow-all rule.
# The group is tagged cursor-pool=<pool_name> so operators can find every
# worker group that belongs to the pool.
resource "aws_security_group" "worker" {
  name_prefix = "${var.pool_name}-worker-"
  description = "Phase A Team Pool worker. Outbound only. No inbound."
  vpc_id      = local.vpc_id

  tags = {
    Name        = "${var.pool_name}-worker"
    cursor-pool = var.pool_name
  }

  lifecycle {
    create_before_destroy = true
  }

  egress {
    description = "DNS to the VPC resolver"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [local.dns_resolver_cidr, local.amazon_dns_linklocal]
  }

  egress {
    description = "DNS to the VPC resolver"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [local.dns_resolver_cidr, local.amazon_dns_linklocal]
  }

  dynamic "egress" {
    for_each = local.secretsmanager_cidrs
    content {
      description = "Secrets Manager interface endpoint"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [egress.value]
    }
  }

  dynamic "egress" {
    for_each = local.cursor_ipv4
    content {
      description = "Cursor host A record at apply time"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["${egress.value}/32"]
    }
  }

  dynamic "egress" {
    for_each = var.lab_egress ? [443, 80] : []
    content {
      description = "Optional lab egress"
      from_port   = egress.value
      to_port     = egress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}
