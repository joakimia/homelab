output "tunnel_id" {
  description = "ID of the tunnel; *.<domain> is a CNAME to <id>.cfargotunnel.com."
  value       = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
}

output "tunnel_token" {
  description = "Token cloudflared runs with (the cloudflared chart's Secret). Read it with tofu output -raw tunnel_token."
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.homelab.token
  sensitive   = true
}

output "cert_manager_api_token" {
  description = "API token for cert-manager's Cloudflare DNS-01 solver (DNS Write and Zone Read on this zone only)."
  value       = cloudflare_account_token.cert_manager.value
  sensitive   = true
}
