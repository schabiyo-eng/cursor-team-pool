# Used only when brittle_cursor_ip_egress is true. Leave that variable false.
# These A records are a snapshot: cursor.com and downloads.cursor.com rotate,
# and a worker pinned to the old addresses cannot finish bootstrap.
data "dns_a_record_set" "cursor" {
  for_each = var.brittle_cursor_ip_egress ? toset(var.cursor_hosts) : toset([])
  host     = each.value
}
