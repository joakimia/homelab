---
name: kubernetes-helm
description: Create, maintain, deploy, inspect, or troubleshoot the homelab Helm charts and deployment profiles (charts in helm/charts, profiles with deploy-set.json in helm/deployment), including the Debian UTM MicroK8s cluster's ingress, DNS, storage, and app secrets.
---

# Homelab Helm charts and the local MicroK8s workflow

Use this skill when you add or change a chart in `helm/charts/`, change a deployment profile in `helm/deployment/`, or work with the UTM development stack in `helm/deployment/dev/local-microk8s-cluster-dev/`.

## Creating or maintaining a chart

Follow the layout the existing charts use (`pgbouncer`, `pgadmin`, and `traefik` are good references):

1. **Files.** Each chart has `Chart.yaml`, `values.yaml`, `values.schema.json`, `README.md`, `scripts/install.sh`, and `templates/`. Put other chart files in their own folder, for example `dashboards/` and `alerts/` for Grafana, and load them with `.Files.Get` or `.Files.Glob`. Do not put them loose in the chart root or `templates/`.
2. **One file per resource.** Name each template after its kind in lowercase: `deployment.yaml`, `statefulset.yaml`, `service.yaml`, `ingress.yaml`, `configmap.yaml`, `serviceaccount.yaml`, `clusterrole.yaml`, `clusterrolebinding.yaml`, `ingressclass.yaml`. Shared named templates go in `_helpers.tpl`. Several resources of the same kind, such as the platform NetworkPolicies, may share one file.
3. **Validation in each template.** Start every template with `required` checks for the values that file uses. Check the parent before the child, use `$_` and the full path, and do not use named variables for validation:
   ```gotemplate
   {{- $_ := required "image settings are required" .Values.image -}}
   {{- $_ := required "image.repository is required" .Values.image.repository -}}
   ```
   Use `fail` for rules such as postgres's `replicaCount must be 1`. Named variables are fine for values reused in the body, as in `platform/templates/network-policies.yaml`.
4. **Value order and probes.** Order top-level values like `homelab-static-web-app`: `namespace`, `name`, (`host`), `image`, `replicaCount`, `resources`, `securityContext`, `podSecurityContext`, `probes` (startup, readiness, liveness), `ports`/`service`, `ingress`, chart-specific keys, then `defaultEnv`, `env`, `defaultSecrets`, `secrets`.
   - `name` names the resources and sets the `app.kubernetes.io/name` label.
   - `service.port`/`containerPort` for one port. With several ports (Traefik): `ports.<name>` for the pod and `service` for how they are exposed.
   - Container ports have fixed names (`http`, `postgresql`, `web`). Probes, Service `targetPort`, and NetworkPolicies refer to them by name, so changing a port number needs no other edits. A NetworkPolicy matches the pod's port, not the Service port.
   - `podSecurityContext` and `securityContext` (container) are rendered with `toYaml`; the defaults are the chart's hardening, `{}` if the image needs root.
   - Each container has startup, readiness, and liveness probes, defined in full in `probes.*` (one handler) and rendered with `toYaml`.
5. **Defaults and schema.** Quote YAML values only when needed (see `AGENTS.md`). `values.yaml` holds every default the chart needs. Profile overlays (`helm/deployment/<env>/<cluster>/<chart>/values.yaml`) contain only what must differ for that cluster, and may be empty. A value without a sensible default is `""  # required` in `values.yaml` and checked with `required`, so every profile has to set it. Update `values.schema.json` in the same change: types, `required`, and `additionalProperties: false` where the chart already uses it.
6. **Environment and Secrets.** Values never hold credentials.
   - `defaultEnv` (`ENV_VAR: value`) and `defaultSecrets` (`<purpose>: {name, env: {ENV_VAR: key}, mountPath, keys}`) hold what the chart needs. A Secret is used as env vars (`env`), as files (`mountPath`, with `keys` that must exist), or both. Prefer files when the app supports `*_FILE` variables.
   - List the default names as `required` in the schema so overlays cannot remove them. `env` and `secrets` stay empty; overlays override or add there. Keep all four as maps (Helm replaces lists).
   - `_helpers.tpl` (`homelab.containerEnv`, `homelab.secretVolumeMounts`, `homelab.secretVolumes`) renders them and fails on empty or duplicate variables and, at install, on missing Secrets or keys. Copy the file unchanged to new workload charts.
   - `scripts/install.sh` creates the chart's own Secrets if missing, never overwrites them, and takes each value from `$<KEY>`, a prompt (`secret_value`), or a default.
7. **`scripts/install.sh` contract.** Use `set -euo pipefail` and find the chart with `chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"`.
   - Check the required commands. Check that the namespace exists: platform owns the namespaces, so never use `--create-namespace`.
   - Create the chart's Secrets. If `Chart.yaml` has dependencies, pin them in `Chart.lock` and run `helm dependency build` here (see `cert-manager`); `charts/` is ignored by Git.
   - End with `helm upgrade --install <release> "$chart_dir" --namespace <ns> "$@"`. Keep the script executable and compatible with bash 3.2.
8. **Ports and security.** Use unprivileged ports: HTTP apps on 8080, pgAdmin on 5050, Authelia on 9091, and Traefik on 8080/8443. Do not use port 80. Do not add `NET_BIND_SERVICE` for ports; add it only when the image binary has it as a file capability (caddy does: without it, exec fails with "operation not permitted"). Drop all capabilities and run as non-root.
9. **Ingress and TLS.** Apps with a UI have `host` and `ingress.className` (`traefik`) and `ingress.tls.enabled` (default `true`) with `clusterIssuer` (`homelab-ca`). Their URL is `https://<host>:8443/`. `ingress.auth.enabled` adds Traefik's `authelia@file` ForwardAuth middleware and limits the route to HTTPS; the app gets `Remote-User`.
10. **Network policy.** Pods use `app.kubernetes.io/name: <name>`. A new workload in a policed namespace needs a matching rule and selector in the platform chart. `hlab-observability` polices ingress only. `hlab-platform`, `hlab-storage`, and `hlab-tools` have no policies: their workloads talk to the API server, which NetworkPolicies cannot select reliably.
11. **README.** Keep it short: what the chart does, how to install it, Secrets, a values table, and the list of templates. Mark scaffolds as such.
12. **Own templates or upstream wrapper.** Write small workloads yourself (Traefik, PostgreSQL, Authelia). Wrap operators and large stacks (CloudNativePG, Longhorn, Prometheus, Grafana, Loki, Authentik, …) as a pinned dependency like `cert-manager`. Put an operator's custom resources in a separate chart installed after it (like `cert-issuers`): Helm cannot install CRDs and their resources in one release.
    - Look up the current chart with `helm show chart`; skip ones marked `deprecated: true` (Grafana's moved to `grafana-community`). Prefer an OCI repository. An HTTPS repository must be registered before `helm dependency build`, so its `scripts/install.sh` runs `helm repo add` when it is missing (see `grafana-alloy`).
    - Set `fullnameOverride` so Service names are stable for other charts, and keep upstream data on StatefulSet claims.
    - A UI gets this chart's own `templates/ingress.yaml` with `host` and `ingress.tls`/`auth`/`backend`, not the upstream Ingress (see `prometheus`, `longhorn`).
    - Upstream components stay in the release namespace; values cannot move one part elsewhere.
13. **Several resources in one template file.** Put all `required` checks at the top, then each resource, with `---` on its own line. A `-}}` or `{{-` right before `---` glues two documents into one, and Helm silently keeps only the last; `check.sh` flags it.
14. **The homelab's own apps.** They are aliases of the `homelab-*` base charts (`homelab-static-web-app`, `homelab-cron-job`, `homelab-shared-pvc`) in the `homelab` chart, as `file://` dependencies. A subchart cannot read its parent's files: the `homelab` chart keeps them in `static-assets/` and `scripts/`, renders ConfigMaps from them, and the base charts mount those through `filesConfigMap` and `scriptConfigMap`. Changing an alias needs `helm dependency update` (it is in `Chart.lock`).
15. **Deploying it.** Add the chart to the profile's `deploy-set.json` in dependency order. Do this only when the chart is implemented, and add an overlay folder only if values differ. Update `helm/charts/README.md` if the profile's chart list changes.
16. **Verify.** Run `tests/check.sh charts` (`helm lint`/`helm template` with each profile overlay) and `tests/check.sh cases`. Add or update cases in `tests/helm/charts/<chart>/` in the same change: `fail-*.yaml` with `# expect: <error text>` for each new `required`, `fail`, or schema rule, and `pass-*.yaml` with `# expect: <rendered text>` for new values and overlay behavior. A schema error names the value's path (`/grafana/persistence/type`); use it as the expected text. Do not deploy unless the user asks.

## Deployment profiles

- `helm/deployment/<env>/<cluster>/` contains only `deploy-set.json`, `deploy.sh`, `install.sh`, `README.md`, and one `<chart>/values.yaml` overlay per chart. Put new profile logic into `install.sh` or `deploy.sh`; do not add more helper scripts. Files the scripts generate (such as `.local/<cluster>.kubeconfig`) go under the directory the script is run from.
- `install.sh <user@host>` (default: SSH) bundles `helm/charts` and the profile, copies it to the node, and runs `deploy.sh --local` there. A local mode is planned, not implemented.
- `deploy.sh <user@host>` (default: remote) fetches the node's kubeconfig over SSH into `.local/<cluster>.kubeconfig`, renames its context to the cluster name (the profile folder name), and runs Helm from the Mac. `--kubeconfig <user@host>` only refreshes that file (for k9s), and `--local` uses the current context.
- `deploy-set.json` has `defaults.helmArgs` and an ordered `releases` list. Each entry is `{ "chart": "...", "helmArgs": [...], "values": "..." }`; only `chart` is required.
- `deploy.sh` reads that file and runs each `helm/charts/<chart>/scripts/install.sh`. It differs per profile and needs `jq`.
- Other profiles are separate targets. Never deploy them automatically.
- Moving resources to another release (as the homepage moved into `homelab`): Helm does not adopt resources another release owns, so uninstall the old release first. A release left `pending-install` or `failed` by an interrupted run must be uninstalled before the next one.

## Before changing a cluster

1. Read the profile README and `AGENTS.md`.
2. Inspect `kubectl config current-context`, cluster nodes, and relevant Helm releases before applying changes.
3. For commands from the Mac, use `.local/<cluster>.kubeconfig` (written by `deploy.sh`) explicitly. Do not rewrite or clean the user's global kubeconfig, and do not deploy this profile to Docker Desktop, AKS, or another context.
4. Use the profile installer, which follows its `deploy-set.json`, or run a single chart with `helm/charts/<chart>/scripts/install.sh --values <profile>/<chart>/values.yaml`. Keep generated secrets in Kubernetes Secrets; never commit them or place them in Helm values.

## Troubleshooting layers

Check the request path one layer at a time:

1. DNS/hosts resolution maps the requested hostname to the VM address; Kubernetes Ingress does not create that mapping.
2. Traefik listens on host ports 8080/8443. Check the Ingress class, host, path, backend Service, and ready endpoints.
3. Confirm the URL scheme and port match the entrypoint (`https://<host>:8443/` or `http://<host>:8080/`). For a certificate warning, check `kubectl get certificate -A` (READY), that the host is in the Ingress `spec.tls`, and that the client trusts `.local/homelab-ca/ca.crt`. Traefik's own default certificate means it found no matching Secret.
4. Check the application pod and logs only after the request has reached the correct Ingress route.

A pod stuck in `ContainerCreating` with `FailedMount ... not found` means a ConfigMap or Secret it mounts is missing: compare `helm get manifest <release>` with what exists in the cluster.

For a temporary HTTP check without changing DNS, follow the profile README's `curl --resolve` examples. A Traefik 404 usually means no route matched the Host/path/entrypoint; it does not by itself prove the application is down. A browser DNS NXDOMAIN means resolution failed before Kubernetes was reached.

## Storage and app relationships

- The UTM profile's `homelab-pvc-storage` class maps to MicroK8s hostpath storage and is created by the platform chart from the profile overlay. A PVC stuck with "storageclass not found" usually means the platform overlay was not applied.
- PostgreSQL is the database backend, PgBouncer is its connection pooler for apps, and pgAdmin is a browser client that connects to PostgreSQL directly (admin sessions do not work well through a pooler). Verify each service and namespace rather than treating the stack as a single release.
- Data one workload owns lives on its StatefulSet claim, which outlives the release. `homelab-shared-pvc` is only for files several workloads share (`ReadWriteMany` on Longhorn in the RKE2 profile).
- Longhorn runs in `hlab-storage` (it needs `privileged`); its `longhorn` StorageClass serves claims in any namespace.
- Telemetry retention is set in Prometheus, Loki, and Tempo. The `homelab` cleanup job deletes only Kubernetes leftovers (old Failed pods and finished Jobs), never their data.
- `hlab-observability` is `baseline`: no `hostPath` or host namespaces. Alloy reads pod logs through the API, and node-exporter runs in the `privileged` `hlab-observability-agents`.
- Keep replicas at one for the current single-node learning environment unless the user explicitly chooses a different topology.
