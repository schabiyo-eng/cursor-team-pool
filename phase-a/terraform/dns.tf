# A records are resolved when the plan is applied, then pinned as /32 egress
# rules. Re-apply when those addresses change; otherwise a strict worker loses
# the path to Cursor. lab_egress=true adds a wide 80/443 rule beside these.
data "dns_a_record_set" "cursor" {
  for_each = toset(var.cursor_hosts)
  host     = each.value
}
