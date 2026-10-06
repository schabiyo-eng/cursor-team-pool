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

  # private_nat opens TCP 443 to 0.0.0.0/0. Domain allowlists belong on the NAT
  # path. The brittle snapshot turns that wide rule off and pins /32s instead.
  # public_lab has no NAT, so it uses the same wide 443 rule unless the
  # snapshot is on. lab_egress always opens 443, and is the only way to open 80.
  allow_wide_https = var.lab_egress || !var.brittle_cursor_ip_egress

  cursor_ipv4 = toset(flatten([
    for record in data.dns_a_record_set.cursor : record.addrs
  ]))
}
