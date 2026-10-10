# PostgreSQL chart

Runs one PostgreSQL 17 instance with a persistent volume claim in `hlab-database`. `replicaCount` is explicitly set to `1` and validated as such because this chart does not configure PostgreSQL replication. It expects a Kubernetes Secret named by `database.existingSecret` with `POSTGRES_DB`, `POSTGRES_USER`, and `POSTGRES_PASSWORD` keys (configurable key names). The chart never stores database credentials in Helm values.

The install script creates this Secret on first install and reuses it on upgrades. The default storage class is the cluster's default; set `storage.storageClassName` in the dev profile if needed.
