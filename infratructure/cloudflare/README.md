# Cloudflare

OpenTofu code for what the homelab uses in Cloudflare: a tunnel into the cluster, the wildcard DNS record, the Access login, and an API token for cert-manager. **Work in progress:** validated offline, not yet applied.

```text
Browser ─HTTPS─▶ Cloudflare edge (*.<domain> certificate, Access login)
                     │  tunnel: cloudflared in the cluster connects out, no open ports at home
                     ▼
                 cloudflared pod ─HTTPS─▶ Traefik :8443 ─▶ Ingress for the requested host
```

| Folder | What it is |
|---|---|
| `terraform/modules/homelab-edge/` | Tunnel with one `*.<domain>` rule to Traefik, proxied wildcard CNAME, Access application for every subdomain (login with a one-time PIN sent to `access_emails`), a bypass for `public_hosts`, optionally the bare domain (`public_apex`), and the cert-manager DNS-01 token. |
| `terraform/dev/` | `joakimia.dev` → the RKE2 cluster (`homelab-rke2-cluster-dev`). The homepage and Authentik (its own login) are public; `https://joakimia.dev/` also shows the homepage. |

`joakimia.com` (prod) is not started. Add it as `terraform/prod/`, a copy of `dev/` with its own `terraform.tfvars` and state path.

## What the code does not create

Do these once in the Cloudflare dashboard:

1. Add the zone (`joakimia.dev`) and point the registrar to Cloudflare's name servers.
2. Open Zero Trust once. Choose a team name and the Free plan (up to 50 users). Terraform adds the One-time PIN login method.
3. Create the API token Terraform runs with (My Profile → API Tokens → Custom token):
   - Account: **Cloudflare Tunnel: Edit**, **Access: Apps and Policies: Edit**, **Access: Organizations, Identity Providers, and Groups: Edit**, **API Tokens: Edit**
   - Zone `joakimia.dev`: **Zone: Read**, **DNS: Edit**

   Keep it outside Git, for example in your password manager. The token can create other tokens, so treat it like an admin password.

## Use

Versions: OpenTofu 1.13.9 (`mise.toml`), Cloudflare provider 5.28.1 (`.terraform.lock.hcl`).

Put the token and your Access address in `.env.local` at the repository root (ignored by Git, `chmod 600`):

```sh
CLOUDFLARE_API_TOKEN=...                      # the token from step 3
CLOUDFLARE_ACCESS_EMAILS=you@example.com      # who may log in through Access, comma-separated
```

```sh
cd infratructure/cloudflare/terraform/dev
set -a; . ../../../../.env.local; set +a
export TF_VAR_access_emails="$CLOUDFLARE_ACCESS_EMAILS"

tofu init
tofu plan
tofu apply
```

The state (`.local/cloudflare/dev.tfstate`) holds the tunnel token and the cert-manager token. It stays on this Mac and is ignored by Git. If you lose it, `tofu import` the resources or delete them in the dashboard and apply again.

If a `*` record already exists in the zone, apply fails. Delete the record, or import it: `tofu import 'module.homelab_edge.cloudflare_dns_record.wildcard' '<zone_id>/<record_id>'`.

Then give the cluster the two secrets. The chart install scripts read them from the environment, or ask for them when you run a profile install from a terminal:

```sh
export TUNNEL_TOKEN="$(tofu output -raw tunnel_token)"                         # cloudflared chart
export CLOUDFLARE_DNS_API_TOKEN="$(tofu output -raw cert_manager_api_token)"   # cert-issuers chart
```

## Things to know

- The free edge certificate covers `joakimia.dev` and one level below it (`grafana.joakimia.dev`). Deeper names (`grafana.lab.joakimia.dev`) need Advanced Certificate Manager.
- Every host goes through Cloudflare, also from the home network: the wildcard record points to the tunnel. `https://<host>:8443/` straight to the node still works with a hosts entry.
- cloudflared verifies Traefik's certificate for the requested host (`match_sn_ito_host`). Until cert-manager has issued the Let's Encrypt certificate, that host returns 502.
- More specific Access applications win, so `public_hosts` bypass the wildcard login. Everything else, including new apps, is behind the login by default.
- Cloudflare limits request bodies to 100 MB on the Free plan (uploads through pgAdmin, for example).
