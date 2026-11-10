# https://<domain>/ goes through the tunnel like a subdomain (the wildcard record does not cover
# the bare domain), and is public: an Ingress in the cluster serves it.

resource "cloudflare_dns_record" "apex" {
  count = var.public_apex ? 1 : 0

  zone_id = local.zone_id
  name    = var.domain
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
  comment = "Homelab: the bare domain goes through the ${var.tunnel_name} tunnel."
}

resource "cloudflare_zero_trust_access_application" "apex" {
  count = var.public_apex ? 1 : 0

  account_id = local.account_id
  name       = "Homelab ${var.domain} (public)"
  type       = "self_hosted"
  domain     = var.domain
  policies = [
    { id = cloudflare_zero_trust_access_policy.everyone.id, precedence = 1 },
  ]
}
