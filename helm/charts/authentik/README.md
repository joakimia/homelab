# authentik chart

Installs [authentik](https://docs.goauthentik.io/) (identity provider: OIDC, SAML, LDAP, proxy) in `hlab-platform` at `https://auth.homelab.com:8443/`. It wraps the upstream `goauthentik` chart, pinned in `Chart.yaml` and `Chart.lock`, with one server and one worker. The database is the in-cluster PostgreSQL (`postgres` chart); the upstream chart's bundled PostgreSQL stays off, and authentik no longer needs Redis. The Ingress is this chart's own template.

Deployed by the RKE2 profile only, at `https://authentik.joakimia.dev/` (port 443 through Cloudflare Tunnel). authentik builds its URLs from the request's Host header, so no URL setting is needed.

## Install

Installed after `postgres`, whose profile overlay must add the role and database:

```yaml
roles:
  authentik:
    name: authentik
    options: [LOGIN]
    passwordSecret:
      name: postgres-authentik
      key: PASSWORD
databases:
  authentik:
    owner: authentik
```

Alone: `./scripts/install.sh --values <profile>/authentik/values.yaml --wait`. The script runs `helm dependency build` first (`charts/` is ignored by Git). The first start runs the database migrations and can take a few minutes. To upgrade, change `version` in `Chart.yaml` and run `helm dependency update`; read the upstream release notes first.

## Secrets

`scripts/install.sh` creates, if missing:

- `authentik-postgres` (`PASSWORD`): copied from `hlab-database/postgres-authentik`, which the postgres chart's installer generates. After changing that password, delete `authentik-postgres` and rerun.
- `authentik-credentials`: `secret-key` (generated; changing it logs everyone out), and `bootstrap-email` and `bootstrap-password` from `AUTHENTIK_BOOTSTRAP_EMAIL` and `AUTHENTIK_BOOTSTRAP_PASSWORD`, a prompt, or the defaults (`admin@homelab.com`, generated password, printed once). authentik reads the bootstrap values only on its first start, to create `akadmin`.

The values cannot hold `secret_key` or the database password: the schema rejects them.

## Hardening and limits

- Non-root (uid 1000), all capabilities dropped, read-only root filesystem with an `emptyDir` on `/tmp`; the server listens on 9000.
- No service account token: the worker cannot deploy outposts into the cluster (that would give it RBAC on Secrets in `hlab-platform`, shared with cert-manager). The embedded outpost works without it.
- No volume at `/data`, so file uploads (icons, backgrounds) are off; use URLs.
- The platform chart's `allow-traefik-to-authentik` policy lets only Traefik connect; apps reach authentik through its public URL.

## Values

| Value | Default | Purpose |
|---|---|---|
| `host` | `auth.homelab.com` | Ingress hostname. |
| `ingress.className` | `traefik` | IngressClass of the Ingress. |
| `ingress.tls.enabled` / `clusterIssuer` | `true` / `homelab-ca` | HTTPS with a cert-manager certificate (`authentik-tls`). |
| `authentik.global.env` | Secret references | Secret key, bootstrap admin, and database password. |
| `authentik.authentik.postgresql` | `postgres.hlab-database`, database and user `authentik` | Connection to the postgres chart. |
| `authentik.server.resources` | 100m/512Mi, limit 1Gi | |
| `authentik.worker.resources` | 50m/384Mi, limit 1Gi | |
| `authentik.serviceAccount.create` | `false` | See above. |

Upstream values go under `authentik:` ([reference](https://github.com/goauthentik/helm/tree/main/charts/authentik)).

## Templates

`ingress.yaml`.
