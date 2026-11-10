output "tunnel_id" {
  value = module.homelab_edge.tunnel_id
}

output "tunnel_token" {
  value     = module.homelab_edge.tunnel_token
  sensitive = true
}

output "cert_manager_api_token" {
  value     = module.homelab_edge.cert_manager_api_token
  sensitive = true
}
