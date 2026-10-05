# Phase C — later

Not implemented.

Reserved for a follow-on after Phase A is proven and Phase B owns the service account key. Likely directions, none of them designed here:

- Scale past one instance (warm capacity, or several workers in the same `cursor-pool` security group).
- A custom AMI so bootstrap no longer downloads the CLI on first boot.
- Tighter, SailPoint-shaped networking: private subnets only, no lab-wide `0.0.0.0/0` egress, and explicit paths for internal git and package hosts.
