# pgAdmin chart

Runs pgAdmin in `hlab-frontend-apps` on port **5050** and publishes it through Traefik at `https://pgadmin.homelab.com:8443/` (and `http://pgadmin.homelab.com:8080/`). The hostname must resolve to the VM, through DNS or `/etc/hosts`.

## Install

Normally installed by the cluster profile's `deploy.sh`. To install it alone:

```sh
./scripts/install.sh --values ../../deployment/dev/local-microk8s-cluster-dev/pgadmin/values.yaml --wait
```

## Secrets

`scripts/install.sh` creates `pgadmin-credentials` on first install. Values come from environment variables with the key names, a prompt (Enter = `admin@homelab.com` or a generated password), or the defaults. A generated login is printed once. Delete the Secret and rerun to get a new login.

After login, register the database through PgBouncer: host `pgbouncer.hlab-database.svc.cluster.local`, port `6432`, user and database `homelab`, and the password from `postgres-credentials`.

## Values

| Value | Default | Purpose |
|---|---|---|
| `ingress.className` | `traefik` | IngressClass of the Ingress. |
| `ingress.tls.enabled` / `clusterIssuer` | `true` / `homelab-ca` | HTTPS with a cert-manager certificate (`<name>-tls`). |
| `host` | `pgadmin.homelab.com` | Ingress hostname. |
| `probes.*` | `httpGet /misc/ping` | Startup, readiness, and liveness probes. |
| `service.port` / `containerPort` | `5050` / `5050` | Service port and `PGADMIN_LISTEN_PORT`. |
| `defaultEnv` | `PGADMIN_LISTEN_PORT` | Environment variables, for example `PGADMIN_CONFIG_*`. |
| `defaultSecrets.login` | `pgadmin-credentials` | Initial login: `PGADMIN_DEFAULT_EMAIL`, `PGADMIN_DEFAULT_PASSWORD`. |

## Templates

`deployment.yaml`, `service.yaml`, `ingress.yaml`.
