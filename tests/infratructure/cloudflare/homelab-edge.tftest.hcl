# Offline tests of the homelab-edge module with a mocked Cloudflare provider: no API calls,
# no credentials. tests/check.sh terraform runs them from the dev root, which pins the
# provider version:
#   tofu -chdir=infratructure/cloudflare/terraform/dev test -test-directory=<this folder>
# Each run uses the module itself (module.source is relative to the dev root).

mock_provider "cloudflare" {
  mock_data "cloudflare_zone" {
    defaults = {
      zone_id = "zone-id"
      account = { id = "account-id", name = "test" }
    }
  }
  mock_data "cloudflare_account_api_token_permission_groups_list" {
    defaults = {
      result = [{ id = "group-id", name = "group", category = "", is_selectable = true, scopes = [] }]
    }
  }
  mock_resource "cloudflare_zero_trust_tunnel_cloudflared" {
    defaults = {
      id = "tunnel-id"
    }
  }
}

variables {
  domain         = "example.dev"
  tunnel_name    = "test-cluster"
  origin_service = "https://traefik.hlab-networking.svc.cluster.local:8443"
  public_hosts   = ["homepage", "authentik"]
  access_emails  = ["a@example.dev", "b@example.dev"]
  public_apex    = true
}

run "routes_every_host_through_the_tunnel" {
  module {
    source = "../modules/homelab-edge"
  }

  command = apply

  assert {
    condition     = jsonencode([for rule in cloudflare_zero_trust_tunnel_cloudflared_config.homelab.config.ingress : rule.hostname]) == jsonencode(["example.dev", "*.example.dev", null])
    error_message = "Tunnel rules must be the bare domain, the wildcard, then the catch-all."
  }
  assert {
    condition     = cloudflare_zero_trust_tunnel_cloudflared_config.homelab.config.ingress[2].service == "http_status:404"
    error_message = "Hosts without a rule must get a 404."
  }
  assert {
    condition     = alltrue([for rule in slice(cloudflare_zero_trust_tunnel_cloudflared_config.homelab.config.ingress, 0, 2) : rule.service == var.origin_service && rule.origin_request.match_sn_ito_host])
    error_message = "Every host goes to Traefik with the requested host as SNI."
  }
  assert {
    condition     = cloudflare_dns_record.wildcard.name == "*.example.dev" && cloudflare_dns_record.wildcard.proxied && cloudflare_dns_record.wildcard.content == "tunnel-id.cfargotunnel.com" && cloudflare_dns_record.apex[0].content == "tunnel-id.cfargotunnel.com"
    error_message = "The wildcard and the bare domain must be CNAMEs to the tunnel."
  }
}

run "logs_in_everyone_except_public_hosts" {
  module {
    source = "../modules/homelab-edge"
  }

  command = apply

  assert {
    condition     = cloudflare_zero_trust_access_application.homelab.domain == "*.example.dev"
    error_message = "Every subdomain needs the Access login by default."
  }
  assert {
    condition     = toset(concat([for app in cloudflare_zero_trust_access_application.public : app.domain], cloudflare_zero_trust_access_application.apex[*].domain)) == toset(["homepage.example.dev", "authentik.example.dev", "example.dev"])
    error_message = "Only public_hosts and the bare domain bypass the login."
  }
  assert {
    condition     = length(cloudflare_zero_trust_access_policy.owner.include) == 2 && cloudflare_zero_trust_access_policy.owner.decision == "allow"
    error_message = "Each address in access_emails gets its own allow rule."
  }
}

run "bare_domain_is_optional" {
  module {
    source = "../modules/homelab-edge"
  }

  command = apply

  variables {
    public_apex  = false
    public_hosts = []
  }

  assert {
    condition     = jsonencode([for rule in cloudflare_zero_trust_tunnel_cloudflared_config.homelab.config.ingress : rule.hostname]) == jsonencode(["*.example.dev", null])
    error_message = "Without public_apex, only the wildcard is routed."
  }
  assert {
    condition     = length(cloudflare_dns_record.apex) == 0
    error_message = "Without public_apex, there is no record for the bare domain."
  }
  assert {
    condition     = length(cloudflare_zero_trust_access_application.public) == 0 && length(cloudflare_zero_trust_access_application.apex) == 0
    error_message = "Nothing bypasses the login without public hosts."
  }
}

run "requires_an_access_address" {
  module {
    source = "../modules/homelab-edge"
  }

  command = plan

  variables {
    access_emails = []
  }

  expect_failures = [var.access_emails]
}
