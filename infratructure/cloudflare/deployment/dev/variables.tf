# Descriptions are in ../modules/homelab-edge/variables.tf. Values: terraform.tfvars, and
# access_emails from CLOUDFLARE_ACCESS_EMAILS in the repository's .env.local (kept out of Git).
variable "domain" {
  type = string
}

variable "tunnel_name" {
  type = string
}

variable "origin_service" {
  type = string
}

variable "public_hosts" {
  type = list(string)
}

variable "public_apex" {
  type = bool
}

# Comma-separated, as in CLOUDFLARE_ACCESS_EMAILS (../deploy.sh sets TF_VAR_access_emails).
# Sensitive so plans, also in public CI logs, do not show the addresses.
variable "access_emails" {
  type      = string
  sensitive = true
}
