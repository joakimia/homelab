# pgAdmin chart

Deploys one pgAdmin replica to `hlab-frontend-apps` and creates an Ingress for `pgadmin.homelab.com`. Adjust `replicaCount` when scaling is desired. It expects the `pgadmin-credentials` Secret, with keys `PGADMIN_DEFAULT_EMAIL` and `PGADMIN_DEFAULT_PASSWORD` by default. The dev install script creates the Secret on first install and prints its generated login once.

After login, register PostgreSQL using host `pgbouncer.hlab-database.svc.cluster.local`, port `6432`, and the PostgreSQL username/password from the database Secret. The chart intentionally keeps credentials out of Helm values. The host must resolve to a Traefik node IP from the Mac.
