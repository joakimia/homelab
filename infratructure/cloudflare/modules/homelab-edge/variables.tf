variable "domain" {
  description = "Cloudflare zone the homelab is published under, for example joakimia.dev."
  type        = string
}

variable "tunnel_name" {
  description = "Name of the Cloudflare Tunnel; the cluster that runs cloudflared."
  type        = string
}

variable "origin_service" {
  description = "Where cloudflared sends every *.<domain> request: Traefik's HTTPS entrypoint in the cluster."
  type        = string
}

variable "public_hosts" {
  description = "Subdomains open to everyone (Access bypass). Every other *.<domain> host requires an Access login."
  type        = list(string)
  default     = []
}

variable "access_emails" {
  description = "Email addresses allowed through Cloudflare Access (one-time PIN login). Kept out of Git."
  type        = list(string)

  validation {
    condition     = length(var.access_emails) > 0
    error_message = "Set at least one address in access_emails, or every protected host is closed."
  }
}

variable "access_session_duration" {
  description = "How long an Access login lasts."
  type        = string
  default     = "24h"
}

variable "public_apex" {
  description = "Also route https://<domain>/ through the tunnel to Traefik, without the Access login. An Ingress in the cluster must use the bare domain as a host."
  type        = bool
  default     = false
}
