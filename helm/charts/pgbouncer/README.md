# PgBouncer chart

Deploys one PgBouncer replica in `hlab-database` and connects to the `postgres` Service. Adjust `replicaCount` when scaling is desired. It expects the existing `postgres-credentials` Secret with `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB` keys. The development install script creates that Secret before installing this chart.

The Secret is used to configure `DB_USER`, `DB_PASSWORD`, and `DB_NAME` in the container. Do not put credentials into Helm values. Default pool mode is `transaction`; configure clients to use the PgBouncer service on port 6432.
