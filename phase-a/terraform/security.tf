# Inline egress so Terraform drops the VPC default allow-all rule.
# The group is tagged cursor-pool=<pool_name> so operators can find every
# worker group that belongs to the pool.
#
# TCP 443 to 0.0.0.0/0 is intentional. cursor.com and downloads.cursor.com are
# CDN-hosted and their A records rotate, so an apply-time /32 list breaks the
# bootstrap curl. Match domains on the NAT path (Network Firewall or a proxy),
# not in this security group. Port 80 stays closed unless lab_egress is set.
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

  # SG-to-SG. A for_each over the endpoint ENI ids fails plan because those
  # ids are known only after apply. This matches ENIs in the endpoint group,
  # which is tighter than the worker subnet CIDR (a shared subnet in public_lab).
  egress {
    description     = "Secrets Manager interface endpoint"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.secretsmanager_endpoint.id]
  }

  dynamic "egress" {
    for_each = local.cursor_ipv4
    content {
      description = "Brittle Cursor A record snapshotted at apply time"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["${egress.value}/32"]
    }
  }

  dynamic "egress" {
    for_each = local.allow_wide_https ? [1] : []
    content {
      description = "HTTPS to the internet. Filter Cursor domains on Network Firewall or a proxy, not with security group IPs."
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  dynamic "egress" {
    for_each = var.lab_egress ? [1] : []
    content {
      description = "Optional lab HTTP egress"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}
