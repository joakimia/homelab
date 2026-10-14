# PostgreSQL chart

Runs one PostgreSQL 17 instance as a StatefulSet with a persistent volume in `hlab-database`. `replicaCount` must be `1` because replication is not configured; the template fails otherwise.

## Install

Normally installed by the cluster profile's `deploy.sh` after `platform` and before `pgbouncer`. To install it alone:

```sh
./scripts/install.sh --values ../../deployment/dev/local-microk8s-cluster-dev/postgres/values.yaml --wait
```

## Secrets

`scripts/install.sh` creates `postgres-credentials` on first install (`POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`). Values come from environment variables with those names, a prompt (Enter = `homelab` or a generated password), or the defaults. PgBouncer uses the same Secret. It also creates `postgres-admin` (`PASSWORD`, from `POSTGRES_ADMIN_PASSWORD`, a prompt, or generated and printed once) for the `homelab-admin` role.

## Roles and databases

A Helm hook Job (`postgres-setup`) runs after every install and upgrade. It creates the roles in `roles` and the databases in `databases` if they are missing, and sets each role's password from its Secret, so changing the Secret and redeploying updates the password. The superuser itself is only set when the data volume is first created. Read the password with:

```sh
kubectl get secret postgres-credentials -n hlab-database -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d; echo
```

## Values

| Value | Default | Purpose |
|---|---|---|
| `defaultEnv` | `PGDATA` | Environment variables. |
| `defaultSecrets.credentials` | `postgres-credentials` | `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`. |
| `probes.*` | `exec pg_isready` | Startup, readiness, and liveness probes. |
| `roles.<key>` | `admin`: `homelab-admin`, `LOGIN CREATEDB CREATEROLE` | `name`, `options`, and `passwordSecret` (`name`, `key`). |
| `databases.<name>.owner` | none | Databases to create, for example for an app. |
| `storage.size` | `2Gi` | PVC size. |
| `storage.storageClassName` | `homelab-pvc-storage` | Created by the platform chart in the UTM profile. |
| `service.port` | `5432` | Service port. |

## Templates

`statefulset.yaml`, `service.yaml`, `job.yaml` (setup hook), `_helpers.tpl`.
