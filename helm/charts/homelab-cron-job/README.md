# Homelab CronJob chart

Base chart for a scheduled shell script: a CronJob that runs `script` with `sh`, a ServiceAccount, and, when `rbac.clusterRules` is set, a ClusterRole and ClusterRoleBinding. The [`homelab`](../homelab/README.md) chart uses it for `periodic-cleanup`.

The script's output goes to the pod log, so Alloy ships it to Loki; kube-state-metrics exports the CronJob and Job status (`kube_cronjob_status_last_successful_time`, `kube_job_status_failed`) to Prometheus. Both can be seen in Grafana.

## Install

Normally included by the `homelab` chart. As its own release: `./scripts/install.sh <release> --values <job values> --wait`. The values must set `name`, `image`, `schedule`, and `script` or `scriptConfigMap`.

## Values

| Value | Default | Purpose |
|---|---|---|
| `namespace` | `hlab-tools` | Namespace of the resources. It has no NetworkPolicies, so scripts can reach the API server. |
| `name` | required | Resource names and `app.kubernetes.io/name`. |
| `image.repository` / `tag` | required | Image with `sh` and the tools the script needs. |
| `securityContext` | uid 65534, no capabilities, read-only root | `/tmp` is a writable `emptyDir`; `HOME` points there. |
| `schedule` / `timeZone` | required / `Etc/UTC` | Cron schedule. |
| `concurrencyPolicy` | `Forbid` | No overlapping runs. |
| `startingDeadlineSeconds` | `600` | Runs missed by more than this are skipped. |
| `successfulJobsHistoryLimit` / `failedJobsHistoryLimit` | `3` / `3` | Finished Jobs the CronJob keeps. |
| `backoffLimit` / `activeDeadlineSeconds` | `1` / `600` | Retries and the time limit of one run. A Job has no probes; the deadline stops a hung run. |
| `script` / `scriptConfigMap` | one is required | Shell script, or an existing ConfigMap with key `run.sh` (for example from a parent chart's `scripts/` folder). Mounted at `/script/run.sh`. |
| `rbac.clusterRules` | `[]` | ClusterRole rules; with none, no API token is mounted. |
| `defaultEnv` / `env`, `defaultSecrets` / `secrets` | `HOME=/tmp` | Environment and Secrets, as in the other workload charts. |

## Templates

`cronjob.yaml`, `configmap.yaml` (the script, when it comes from the values), `serviceaccount.yaml`, `clusterrole.yaml`, `clusterrolebinding.yaml`.
