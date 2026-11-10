# Dev environment: *.joakimia.dev through a tunnel to the RKE2 cluster on Proxmox.
module "homelab_edge" {
  source = "../modules/homelab-edge"

  domain         = var.domain
  tunnel_name    = var.tunnel_name
  origin_service = var.origin_service
  public_hosts   = var.public_hosts
  access_emails  = [for email in split(",", var.access_emails) : trimspace(email) if trimspace(email) != ""]
  public_apex    = var.public_apex
}
