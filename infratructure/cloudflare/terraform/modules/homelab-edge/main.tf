data "cloudflare_zone" "homelab" {
  filter = {
    name = var.domain
  }
}

locals {
  account_id = data.cloudflare_zone.homelab.account.id
  zone_id    = data.cloudflare_zone.homelab.zone_id
  wildcard   = "*.${var.domain}"
}

# Remotely managed tunnel: the ingress rules live in Cloudflare, cloudflared only needs the token.
resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab" {
  account_id = local.account_id
  name       = var.tunnel_name
  config_src = "cloudflare"
}

# Every subdomain (and the bare domain with public_apex) goes to Traefik, which routes by Host,
# so new apps need only an Ingress. Requests for other hosts get a 404.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab" {
  account_id = local.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id

  config = {
    ingress = concat(
      [
        for hostname in concat(var.public_apex ? [var.domain] : [], [local.wildcard]) : {
          hostname = hostname
          service  = var.origin_service
          origin_request = {
            # Send the requested host as SNI, so Traefik presents (and cloudflared verifies)
            # that host's Let's Encrypt certificate.
            match_sn_ito_host = true
          }
        }
      ],
      [{ service = "http_status:404" }],
    )
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "homelab" {
  account_id = local.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
}

# Proxied, so clients reach Cloudflare's edge (and its *.<domain> certificate), never the LAN.
resource "cloudflare_dns_record" "wildcard" {
  zone_id = local.zone_id
  name    = local.wildcard
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
  comment = "Homelab: every subdomain goes through the ${var.tunnel_name} tunnel."
}
