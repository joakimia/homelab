# Helm charts

All charts the homelab can use. A cluster profile in `../deployment/<env>/<cluster>/` decides which of them are deployed. The UTM development profile ([README](../deployment/dev/mac-utm-microk8s-cluster/README.md)) deploys:

| Chart | Namespace | What it does |
|---|---|---|
| [`platform`](platform/README.md) | `default` | Namespaces, Pod Security labels, NetworkPolicies, StorageClass. Always first. |
| [`traefik`](traefik/README.md) | `hlab-networking` | Ingress controller on host ports 8080 (HTTP) and 8443. |
| [`postgres`](postgres/README.md) | `hlab-database` | PostgreSQL with a PVC; creates `postgres-credentials`. |
| [`pgbouncer`](pgbouncer/README.md) | `hlab-database` | Connection pool on 6432. |
| [`pgadmin`](pgadmin/README.md) | `hlab-frontend-apps` | pgAdmin on 5050, `http://pgadmin.homelab.com:8080/`. |
| [`homepage`](homepage/README.md) | `hlab-frontend-apps` | Caddy page, `http://homepage.homelab.com:8080/`. |

The other directories (Grafana, Loki, cert-manager, and so on) are scaffolds and are not deployed.

## How a chart is laid out

```text
<chart>/
  Chart.yaml
  values.yaml           # every default the chart needs
  values.schema.json    # Helm validates values against it before rendering
  README.md
  scripts/install.sh    # creates the chart's Secrets, then helm upgrade --install
  templates/            # one file per Kubernetes resource
  <extra>/              # chart files such as dashboards/ or alerts/, in their own folder
```

Each template starts with `required` checks for the values it uses, for example `{{- $_ := required "image.tag is required" .Values.image.tag -}}`.

## How it is deployed

`scripts/install.sh [helm flags]` installs one chart. The profile's `deploy.sh` runs these scripts in the order of its `deploy-set.json`, adding the profile's `<chart>/values.yaml` overlay and flags such as `--wait`. From the Mac, the profile's `install.sh debian@<vm-ip>` copies the charts to the VM and deploys there, while `deploy.sh debian@<vm-ip>` deploys from the Mac against the VM's API. See [`../README.md`](../README.md) for the `deploy-set.json` format.
