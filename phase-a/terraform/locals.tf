locals {
  use_private_nat = var.network_mode == "private_nat"

  vpc_id   = var.vpc_id != null ? data.aws_vpc.by_id[0].id : data.aws_vpc.default[0].id
  vpc_cidr = var.vpc_id != null ? data.aws_vpc.by_id[0].cidr_block : data.aws_vpc.default[0].cidr_block

  public_subnet_id = (
    var.public_subnet_id != null ? var.public_subnet_id : sort(data.aws_subnets.public[0].ids)[0]
  )

  private_subnet_cidr = (
    var.private_subnet_cidr != null ? var.private_subnet_cidr : cidrsubnet(local.vpc_cidr, 8, 250)
  )

  worker_subnet_id     = local.use_private_nat ? aws_subnet.private[0].id : local.public_subnet_id
  associate_public_ip  = !local.use_private_nat
  secret_name          = coalesce(var.secret_name, "cursor/${var.pool_name}/service-account-key")
  dns_resolver_cidr    = "${cidrhost(local.vpc_cidr, 2)}/32"
  amazon_dns_linklocal = "169.254.169.253/32"
  secretsmanager_cidrs = [for eni in data.aws_network_interface.secretsmanager : "${eni.private_ip}/32"]

  cursor_ipv4 = toset(flatten([
    for record in data.dns_a_record_set.cursor : record.addrs
  ]))
}
