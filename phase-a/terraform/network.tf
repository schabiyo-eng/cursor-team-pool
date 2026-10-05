data "aws_vpc" "default" {
  count   = var.vpc_id == null ? 1 : 0
  default = true
}

data "aws_vpc" "by_id" {
  count = var.vpc_id == null ? 0 : 1
  id    = var.vpc_id
}

data "aws_subnets" "public" {
  count = var.public_subnet_id == null ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }

  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

data "aws_subnet" "public" {
  id = local.public_subnet_id
}

resource "aws_subnet" "private" {
  count = local.use_private_nat ? 1 : 0

  vpc_id                  = local.vpc_id
  cidr_block              = local.private_subnet_cidr
  availability_zone       = data.aws_subnet.public.availability_zone
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.pool_name}-worker-private"
  }
}

resource "aws_eip" "nat" {
  count  = local.use_private_nat ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "${var.pool_name}-worker-nat"
  }
}

resource "aws_nat_gateway" "worker" {
  count = local.use_private_nat ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = local.public_subnet_id

  tags = {
    Name = "${var.pool_name}-worker"
  }

  depends_on = [aws_eip.nat]
}

resource "aws_route_table" "private" {
  count  = local.use_private_nat ? 1 : 0
  vpc_id = local.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.worker[0].id
  }

  tags = {
    Name = "${var.pool_name}-worker-private"
  }
}

resource "aws_route_table_association" "private" {
  count = local.use_private_nat ? 1 : 0

  subnet_id      = aws_subnet.private[0].id
  route_table_id = aws_route_table.private[0].id
}

# Interface endpoint so GetSecretValue stays on the VPC network and the worker
# security group does not need a public path to secretsmanager.*.amazonaws.com.
# Worker egress references this security group. The endpoint ENI ids and
# private IPs are only known after apply, so they cannot be for_each keys.
resource "aws_security_group" "secretsmanager_endpoint" {
  name_prefix = "${var.pool_name}-sm-vpce-"
  description = "Secrets Manager interface endpoint for the Phase A worker."
  vpc_id      = local.vpc_id

  egress = []

  tags = {
    Name = "${var.pool_name}-secretsmanager-endpoint"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "secretsmanager_from_worker" {
  security_group_id            = aws_security_group.secretsmanager_endpoint.id
  referenced_security_group_id = aws_security_group.worker.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "Worker GetSecretValue"
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [local.worker_subnet_id]
  security_group_ids  = [aws_security_group.secretsmanager_endpoint.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.pool_name}-secretsmanager"
  }
}
