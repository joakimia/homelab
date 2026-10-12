# pgAdmin chart

Runs pgAdmin in `hlab-frontend-apps` on port **5050** and publishes it through Traefik at `http://pgadmin.homelab.com:8080/`. The hostname must resolve to the VM, through DNS or `/etc/hosts`.

## Install

Normally installed by the cluster profile's `deploy.sh`. To install it alone:

```sh
./scripts/install.sh --values ../../deployment/dev/local-microk8s-cluster-dev/pgadmin/values.yaml --wait
```

## Secrets

`scripts/install.sh` creates `pgadmin-credentials` on first install (`PGADMIN_DEFAULT_EMAIL`, default `admin@homelab.com`, override with `PGADMIN_DEFAULT_EMAIL=...`, and a random `PGADMIN_DEFAULT_PASSWORD`) and prints the login once. Delete the Secret and rerun the script to get a new login.

After login, register the database through PgBouncer: host `pgbouncer.hlab-database.svc.cluster.local`, port `6432`, user and database `homelab`, and the password from `postgres-credentials`.

## Values

| Value | Default | Purpose |
|---|---|---|
| `host` | `pgadmin.homelab.com` | Ingress hostname. |
| `service.port` / `containerPort` | `5050` / `5050` | Service port and `PGADMIN_LISTEN_PORT`. |
| `existingSecret`, `emailSecretKey`, `passwordSecretKey` | `pgadmin-credentials` | Secret and key names. |

## Templates

`deployment.yaml`, `service.yaml`, `ingress.yaml`.
