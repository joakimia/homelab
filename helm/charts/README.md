# Helm charts

All charts the homelab can use. A cluster profile in `../deployment/<env>/<cluster>/` decides which of them are deployed. The UTM development profile ([README](../deployment/dev/local-microk8s-cluster-dev/README.md)) deploys:

| Chart | Namespace | What it does |
|---|---|---|
| [`platform`](platform/README.md) | `default` | Namespaces, Pod Security labels, NetworkPolicies, StorageClass. Always first. |
| [`cert-manager`](cert-manager/README.md) | `hlab-platform` | Upstream cert-manager 1.21.2; issues the Ingress certificates. |
| [`cert-issuers`](cert-issuers/README.md) | `hlab-platform` | `homelab-ca` ClusterIssuer backed by a local CA that the Mac trusts. |
| [`traefik`](traefik/README.md) | `hlab-networking` | Ingress controller on host ports 8080 (HTTP) and 8443 (HTTPS). |
| [`postgres`](postgres/README.md) | `hlab-database` | PostgreSQL with a PVC; creates `postgres-credentials`. |
| [`pgbouncer`](pgbouncer/README.md) | `hlab-database` | Connection pool on 6432. |
| [`pgadmin`](pgadmin/README.md) | `hlab-frontend-apps` | pgAdmin on 5050, `https://pgadmin.homelab.com:8443/`. |
| [`homepage`](homepage/README.md) | `hlab-frontend-apps` | Caddy page, `https://homepage.homelab.com:8443/`. |
| [`authelia`](authelia/README.md) | `hlab-platform` | Login portal, `https://auth.homelab.com:8443/` (MicroK8s profile only). |

The [RKE2 development profile](../deployment/dev/homelab-rke2-cluster-dev/README.md) (work in progress) deploys the same charts plus:

| Chart | Namespace | What it does |
|---|---|---|
| [`local-path-provisioner`](local-path-provisioner/README.md) | `hlab-storage` | Node-local volumes for `homelab-pvc-storage` on clusters without a storage addon. |

The other directories (Grafana, Loki, and so on) are scaffolds and are not deployed.

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

Workload charts share these values:

- `probes.startup|readiness|liveness`: full Kubernetes probes with a named port.
- `defaultEnv` (`ENV_VAR: value`) and `defaultSecrets` (`<purpose>: {name, env: {ENV_VAR: key}}`): what the chart needs; all required.
- `env` and `secrets`: empty in the chart. Profile overlays override or add entries here; Secrets you add must be created by hand. Installs fail if a Secret or key is missing.

## How it is deployed

`scripts/install.sh [helm flags]` installs one chart. The profile's `deploy.sh` runs these scripts in the order of its `deploy-set.json`, adding the profile's `<chart>/values.yaml` overlay and flags such as `--wait`. From the Mac, the profile's `install.sh debian@<vm-ip>` copies the charts to the VM and deploys there, while `deploy.sh debian@<vm-ip>` deploys from the Mac against the VM's API. See [`../README.md`](../README.md) for the `deploy-set.json` format.
