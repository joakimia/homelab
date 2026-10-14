# PgBouncer chart

Runs a PgBouncer connection pool in `hlab-database` in front of the `postgres` Service. Clients, such as pgAdmin, connect to `pgbouncer.hlab-database.svc.cluster.local:6432`.

## Install

Normally installed by the cluster profile's `deploy.sh` after `postgres`. To install it alone:

```sh
./scripts/install.sh --values ../../deployment/dev/local-microk8s-cluster-dev/pgbouncer/values.yaml --wait
```

## Secrets

Uses `postgres-credentials`, which the postgres chart's install script creates. Install postgres first.

## Values

| Value | Default | Purpose |
|---|---|---|
| `defaultEnv` | `DB_HOST=postgres`, `POOL_MODE=transaction`, … | Backend and pool settings ([image docs](https://github.com/edoburu/docker-pgbouncer)). |
| `defaultSecrets.database` | `postgres-credentials` | `DB_NAME`, `DB_USER`, `DB_PASSWORD`. |
| `probes.*` | `tcpSocket` | Startup, readiness, and liveness probes. |
| `service.port` / `containerPort` | `6432` / `5432` | Port clients use / port PgBouncer listens on in the pod. |

## Templates

`deployment.yaml`, `service.yaml`.
