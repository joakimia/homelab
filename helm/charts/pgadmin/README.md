# pgAdmin chart

Runs pgAdmin in `hlab-frontend-apps` on port **5050** and publishes it through Traefik at `https://pgadmin.homelab.com:8443/` (and `http://pgadmin.homelab.com:8080/`). The hostname must resolve to the VM, through DNS or `/etc/hosts`.

## Install

Normally installed by the cluster profile's `deploy.sh`. To install it alone:

```sh
./scripts/install.sh --values ../../deployment/dev/local-microk8s-cluster-dev/pgadmin/values.yaml --wait
```

## Secrets

`scripts/install.sh` creates `pgadmin-credentials` on first install. Values come from environment variables with the key names, a prompt (Enter = `admin@homelab.com` or a generated password), or the defaults. A generated login is printed once. Delete the Secret and rerun to get a new login.

After login, register PostgreSQL directly (not through PgBouncer): host `postgres.hlab-database.svc.cluster.local`, port `5432`, user and database `homelab`, and the password from `postgres-credentials`.

## Login through Authelia

With `ingress.auth.enabled`, set these in `env` so pgAdmin logs in the Authelia user from the `Remote-User` header (see the MicroK8s overlay):

- `PGADMIN_CONFIG_AUTHENTICATION_SOURCES: "['webserver']"`, `PGADMIN_CONFIG_WEBSERVER_REMOTE_USER: "'Remote-User'"`, `PGADMIN_CONFIG_WEBSERVER_REMOTE_USER_FROM_HEADER: "True"`, `PGADMIN_CONFIG_WEBSERVER_AUTO_CREATE_USER: "True"`.
- `PGADMIN_CONFIG_WEBSERVER_TRUSTED_PROXIES`: the pod network, so only Traefik can assert the user. pgAdmin compares plain IPv4 addresses, so also set `PGADMIN_LISTEN_ADDRESS: 0.0.0.0`.

## Values

| Value | Default | Purpose |
|---|---|---|
| `ingress.className` | `traefik` | IngressClass of the Ingress. |
| `ingress.tls.enabled` / `clusterIssuer` | `true` / `homelab-ca` | HTTPS with a cert-manager certificate (`<name>-tls`). |
| `ingress.auth.enabled` / `middleware` | `false` / `authelia@file` | Login through Authelia; the route is then HTTPS only. |
| `host` | `pgadmin.homelab.com` | Ingress hostname. |
| `probes.*` | `httpGet /misc/ping` | Startup, readiness, and liveness probes. |
| `service.port` / `containerPort` | `5050` / `5050` | Service port and `PGADMIN_LISTEN_PORT`. |
| `defaultEnv` | `PGADMIN_LISTEN_PORT` | Environment variables, for example `PGADMIN_CONFIG_*`. |
| `defaultSecrets.login` | `pgadmin-credentials` | Initial login: `PGADMIN_DEFAULT_EMAIL`, `PGADMIN_DEFAULT_PASSWORD`. |

## Templates

`deployment.yaml`, `service.yaml`, `ingress.yaml`.
