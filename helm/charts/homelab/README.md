# Homelab chart

The homelab's own apps in one release, built from the homelab base charts. Each app is a local dependency under an alias in `Chart.yaml`, configured under that alias in `values.yaml`:

| Alias | Base chart | Namespace | What it does |
|---|---|---|---|
| `homelab-frontend` | [`homelab-static-web-app`](../homelab-static-web-app/README.md) | `hlab-frontend-apps` | Start page at `https://homepage.homelab.com:8443/`. |
| `homelab-periodic-cleanup` | [`homelab-cron-job`](../homelab-cron-job/README.md) | `hlab-tools` | Daily at 03:30 UTC: deletes leftovers older than 7 days. |
| `homelab-shared-pvc` | [`homelab-shared-pvc`](../homelab-shared-pvc/README.md) | `hlab-filestore` | Shared claim; off by default, on (Longhorn, `ReadWriteMany`) in the RKE2 profile. |

Files the apps use live in this chart, not in the values: `static-assets/` holds the homepage files (flat names; served within about a minute of an upgrade, without a restart), and `scripts/periodic-cleanup.sh` the cleanup script. `templates/configmap.yaml` puts them in ConfigMaps, which the base charts mount through `filesConfigMap` and `scriptConfigMap`.

Another app is one more alias of a base chart. Charts that wrap upstream software (Traefik, PostgreSQL, Grafana, …) stay separate releases.

## Periodic cleanup

`scripts/periodic-cleanup.sh`: in namespaces with the platform chart's `homelab.jamundsen.local/tier` label, the job deletes Failed pods that no Job owns (for example evicted pods) and finished Jobs that no CronJob owns, once they are older than `RETENTION_DAYS`. CronJobs keep their own history (`successfulJobsHistoryLimit`).

It does not touch metrics, logs, or traces: Prometheus (3 days), Loki (72h), and Tempo (72h) enforce their own retention, and deleting their files from outside would corrupt them. The job's own output is in Loki (`{namespace="hlab-tools", app="periodic-cleanup"}`), and its status is in Prometheus (`kube_cronjob_status_last_successful_time{cronjob="periodic-cleanup"}`, `kube_job_status_failed`).

Set `DRY_RUN: true` in `homelab-periodic-cleanup.defaultEnv` to only list what would be deleted. To run it now: `kubectl -n hlab-tools create job --from=cronjob/periodic-cleanup cleanup-now`.

## Install

Installed by the profiles after pgAdmin. Alone: `./scripts/install.sh --wait`. The script packages the base charts into `charts/` (`helm dependency build`; ignored by Git), so changes to a base chart take effect on the next install. The release record is kept in `default`; the resources use the namespaces above, which the platform chart creates.

The homepage used to be its own `homepage` release. Helm does not adopt resources another release owns, so remove that release once before the first install (the page is down until the install finishes); the script stops and says so:

```sh
helm uninstall homepage --namespace hlab-frontend-apps
```

## Values

| Value | Default | Purpose |
|---|---|---|
| `homelab-frontend.filesConfigMap` | `homepage-static-assets` | ConfigMap made from `static-assets/`. |
| `homelab-frontend.ingress.catchAll` | `true` | `http://<node-ip>:8080/` opens the homepage too; off with `ingress.auth`. |
| `homelab-periodic-cleanup.enabled` | `true` | Install the cleanup CronJob. |
| `homelab-periodic-cleanup.scriptConfigMap` | `periodic-cleanup-script` | ConfigMap made from `scripts/periodic-cleanup.sh`. |
| `homelab-periodic-cleanup.schedule` | `30 3 * * *` | When it runs (UTC). |
| `homelab-periodic-cleanup.defaultEnv` | `RETENTION_DAYS: 7`, `DRY_RUN: false`, `NAMESPACE_LABEL` | What it deletes. |
| `homelab-periodic-cleanup.rbac.clusterRules` | list namespaces; list and delete pods and Jobs | Its ClusterRole. |
| `homelab-shared-pvc.enabled` | `false` | Create the shared claim. |

## Templates

`configmap.yaml` (the homepage files and the cleanup script). The rest comes from the base charts.
