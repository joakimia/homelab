# Account-owned API token for cert-manager's DNS-01 solver (Let's Encrypt): it can only edit DNS
# records in this zone. The token Terraform runs with needs "Account API Tokens: Edit" for it.

data "cloudflare_account_api_token_permission_groups_list" "dns_write" {
  account_id = local.account_id
  name       = "DNS Write"
  scope      = "com.cloudflare.api.account.zone"
}

data "cloudflare_account_api_token_permission_groups_list" "zone_read" {
  account_id = local.account_id
  name       = "Zone Read"
  scope      = "com.cloudflare.api.account.zone"
}

resource "cloudflare_account_token" "cert_manager" {
  account_id = local.account_id
  name       = "${var.tunnel_name} cert-manager DNS-01"
  policies = [
    {
      effect = "allow"
      permission_groups = [
        { id = data.cloudflare_account_api_token_permission_groups_list.dns_write.result[0].id },
        { id = data.cloudflare_account_api_token_permission_groups_list.zone_read.result[0].id },
      ]
      resources = jsonencode({ "com.cloudflare.api.account.zone.${local.zone_id}" = "*" })
    },
  ]
}
