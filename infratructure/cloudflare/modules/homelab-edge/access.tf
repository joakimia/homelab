# Cloudflare Access in front of every subdomain: only access_emails get through (one-time PIN
# by email). Hosts in public_hosts get a more specific application that bypasses the login.

# Login with a code sent by email; no outside identity provider needed. A Zero Trust account
# has at most one, so import it if it already exists.
resource "cloudflare_zero_trust_access_identity_provider" "one_time_pin" {
  account_id = local.account_id
  name       = "One-time PIN"
  type       = "onetimepin"
  config     = {}
}

resource "cloudflare_zero_trust_access_policy" "owner" {
  account_id = local.account_id
  name       = "Homelab owner"
  decision   = "allow"
  include    = [for email in var.access_emails : { email = { email = email } }]
}

resource "cloudflare_zero_trust_access_policy" "everyone" {
  account_id = local.account_id
  name       = "Homelab public"
  decision   = "bypass"
  include    = [{ everyone = {} }]
}

resource "cloudflare_zero_trust_access_application" "homelab" {
  account_id       = local.account_id
  name             = "Homelab"
  type             = "self_hosted"
  domain           = local.wildcard
  session_duration = var.access_session_duration
  allowed_idps     = [cloudflare_zero_trust_access_identity_provider.one_time_pin.id]
  policies = [
    { id = cloudflare_zero_trust_access_policy.owner.id, precedence = 1 },
  ]
}

resource "cloudflare_zero_trust_access_application" "public" {
  for_each = toset(var.public_hosts)

  account_id = local.account_id
  name       = "Homelab ${each.key} (public)"
  type       = "self_hosted"
  domain     = "${each.key}.${var.domain}"
  policies = [
    { id = cloudflare_zero_trust_access_policy.everyone.id, precedence = 1 },
  ]
}
