# Grafana chart

Installs [Grafana](https://grafana.com/docs/grafana/latest/) in `hlab-observability` at `https://grafana.homelab.com:8443/`, with Prometheus, Loki, and Tempo provisioned as data sources. It wraps the upstream chart from `grafana-community` (the `grafana/grafana` chart is deprecated), pinned in `Chart.yaml` and `Chart.lock`. The Ingress is this chart's own template, so it follows the homelab `ingress.tls` and `ingress.auth` values.

Grafana runs as a StatefulSet: its SQLite database (users, dashboards made in the UI) is on a `homelab-pvc-storage` claim that is kept on uninstall.

## Dashboards

`dashboards/*.json` are provisioned into the **Homelab** folder and are read-only in the UI; change them in Git (or save a copy in the UI under another name):

- **Nodes**: CPU, memory, filesystems, load, and network per node (node-exporter).
- **Workloads**: running and not-ready pods, restarts, failed Jobs, CPU and memory per pod, and time since each CronJob last succeeded (kube-state-metrics, cAdvisor).
- **Logs and events**: pod logs by namespace, app, and text, and Kubernetes events (Loki).

## Install

Installed by the profiles after Prometheus, Loki, and Tempo. Alone: `./scripts/install.sh --wait`. The script runs `helm dependency build` first (`charts/` is ignored by Git). To upgrade, change `version` in `Chart.yaml` and run `helm dependency update`.

## Secrets

`scripts/install.sh` creates `grafana-admin` (`admin-user`, `admin-password`) on first install, from `GRAFANA_ADMIN_USER` and `GRAFANA_ADMIN_PASSWORD`, a prompt, or the defaults (`admin`, generated password, printed once). Delete the Secret and rerun to get a new login; Grafana only applies it to a new database.

## Login through Authelia

With `ingress.auth.enabled`, turn on `grafana."grafana.ini"."auth.proxy"` so Grafana logs in the Authelia user from the `Remote-User` header (see the MicroK8s overlay):

- `whitelist`: the pod network, so only Traefik can assert the user. Requests with the header from other addresses get 401.
- New users are created as Viewers. An Authelia user with the Grafana admin's name (`admin` by default for both) logs in as the Grafana admin.

The chart fails to render if `auth.proxy` is on without `ingress.auth` (anyone could send the header) or without `whitelist`.

## Values

| Value | Default | Purpose |
|---|---|---|
| `host` | `grafana.homelab.com` | Ingress hostname; must equal `grafana."grafana.ini".server.domain`. |
| `ingress.className` | `traefik` | IngressClass of the Ingress. |
| `ingress.tls.enabled` / `clusterIssuer` | `true` / `homelab-ca` | HTTPS with a cert-manager certificate (`grafana-tls`). |
| `ingress.auth.enabled` / `middleware` | `false` / `authelia@file` | Login through Authelia; the route is then HTTPS only. |
| `grafana.admin.existingSecret` | `grafana-admin` | Admin login from `scripts/install.sh`. |
| `grafana.persistence` | StatefulSet, 1Gi, `homelab-pvc-storage` | Grafana database. |
| `grafana."grafana.ini"."auth.proxy"` | off, `Remote-User` | Login from Authelia headers. |
| `grafana.datasources` | Prometheus (default), Loki, Tempo | Provisioned data sources; Tempo links traces to Loki logs. |
| `grafana.dashboardsConfigMaps.homelab` | `grafana-dashboards` | ConfigMap made from `dashboards/`; the provider in `dashboardProviders` reads it. |
| `grafana.resources` | 50m/128Mi, limit 512Mi | Small requests for one node. |

Upstream values go under `grafana:` ([reference](https://github.com/grafana-community/helm-charts/tree/main/charts/grafana)).

## Templates

`ingress.yaml`, `configmap.yaml` (the dashboards).
