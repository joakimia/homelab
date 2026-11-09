# Cloudflare

OpenTofu code for what the homelab uses in Cloudflare: a tunnel into the cluster, the wildcard DNS record, the Access login, and an API token for cert-manager. **Work in progress:** the dev environment is applied (2026-11-09); state in R2 and CI are set up but not yet run.

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

4. Create the R2 bucket for the state: R2 → Create bucket `joakimia-homelab-tfstate` (private, no public access).
5. Create an R2 API token (R2 → Manage API tokens): **Object Read & Write**, only for that bucket. Keep its Access Key ID and Secret Access Key (the S3 credentials).
6. For CI, create a second API token like the one in step 3, but **without IP filtering** (GitHub's runners have changing addresses). Keep your IP-restricted token for the Mac.

## Use

Versions: OpenTofu 1.13.9 (`mise.toml`), Cloudflare provider 5.28.1 (`.terraform.lock.hcl`).

Put the tokens and your Access address in `.env.local` at the repository root (ignored by Git, `chmod 600`):

```sh
CLOUDFLARE_API_TOKEN=...                      # the token from step 3
CLOUDFLARE_ACCESS_EMAILS=you@example.com      # who may log in through Access, comma-separated
R2_ACCESS_KEY_ID=...                          # the R2 token from step 5
R2_SECRET_ACCESS_KEY=...
```

`terraform/deploy.sh` loads `.env.local` when it exists, maps the names to what `tofu` reads, and runs `tofu` in the environment's folder:

```sh
infratructure/cloudflare/terraform/deploy.sh dev plan    # writes and prints ./.local/cloudflare/dev.tfplan
infratructure/cloudflare/terraform/deploy.sh dev apply   # applies exactly that plan
infratructure/cloudflare/terraform/deploy.sh dev init    # only init, for tofu output and other commands
```

The state is in R2 (`cloudflare/dev.tfstate` in the bucket) and holds the tunnel token and the cert-manager token. A `.tflock` object next to it locks it during plan and apply. The plan file holds secrets too; it is written under `.local/` (ignored) and deleted after apply.

**Moving from the local state (once):** with the R2 variables set, run `deploy.sh dev migrate`. It copies `.local/cloudflare/dev.tfstate` to R2 (`tofu init -migrate-state`). Then run `deploy.sh dev plan`, which should show no changes, and keep the old file as a backup until you are sure.

If a `*` record already exists in the zone, apply fails. Delete the record, or import it: `tofu import 'module.homelab_edge.cloudflare_dns_record.wildcard' '<zone_id>/<record_id>'`.

Then give the cluster the two secrets. The chart install scripts read them from the environment, or ask for them when you run a profile install from a terminal. `tofu output` reads the state from R2: run `deploy.sh dev init` first, and export the R2 keys as `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` in the folder `terraform/dev/`:

```sh
export TUNNEL_TOKEN="$(tofu output -raw tunnel_token)"                         # cloudflared chart
export CLOUDFLARE_DNS_API_TOKEN="$(tofu output -raw cert_manager_api_token)"   # cert-issuers chart
```

## CI

`.github/workflows/cd.yml` runs `deploy.sh` for dev when files under `infratructure/cloudflare/` change:

- **Pull request** from this repository: plan, shown in the job summary. Forks get no secrets, so their PRs are skipped.
- **Push to `main`**, or a manual run on `main`: plan and apply. Only one apply runs at a time.

Both jobs use the GitHub environment `dev` and its secrets `CLOUDFLARE_API_TOKEN` (the CI token from step 6), `CLOUDFLARE_ACCESS_EMAILS`, `R2_ACCESS_KEY_ID`, and `R2_SECRET_ACCESS_KEY`. Environment secrets need `environment: dev` on the job, so the PR plan uses the environment too:

- Keep **Deployment branches** at "No restriction", or PR plans cannot read the secrets.
- Do not add **Required reviewers**, or every PR plan waits for approval as well. Merging to `main` is the approval. For a gate on apply only, add a second environment for plans with a read-only token.

The plan job runs code from the PR branch with the secrets. In a public repository only people with write access can open PRs from branches here; keep it that way.

Plans do not show the Access addresses (`access_emails` is sensitive) or the token outputs, and `deploy.sh` masks each address in the logs.

## Things to know

- The free edge certificate covers `joakimia.dev` and one level below it (`grafana.joakimia.dev`). Deeper names (`grafana.lab.joakimia.dev`) need Advanced Certificate Manager.
- Every host goes through Cloudflare, also from the home network: the wildcard record points to the tunnel. `https://<host>:8443/` straight to the node still works with a hosts entry.
- cloudflared verifies Traefik's certificate for the requested host (`match_sn_ito_host`). Until cert-manager has issued the Let's Encrypt certificate, that host returns 502.
- More specific Access applications win, so `public_hosts` bypass the wildcard login. Everything else, including new apps, is behind the login by default.
- Cloudflare limits request bodies to 100 MB on the Free plan (uploads through pgAdmin, for example).
