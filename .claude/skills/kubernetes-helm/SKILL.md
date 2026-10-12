---
name: kubernetes-helm
description: Create, maintain, deploy, inspect, or troubleshoot the homelab Helm charts and deployment profiles (charts in helm/charts, profiles with deploy-set.json in helm/deployment), including the Debian UTM MicroK8s cluster's ingress, DNS, storage, and app secrets.
---

# Homelab Helm charts and the local MicroK8s workflow

Use this skill when you add or change a chart in `helm/charts/`, change a deployment profile in `helm/deployment/`, or work with the UTM development stack in `helm/deployment/dev/local-microk8s-cluster-dev/`.

## Creating or maintaining a chart

Follow the layout the existing charts use (`pgadmin`, `postgres`, and `traefik` are good references):

1. **Files.** Each chart has `Chart.yaml`, `values.yaml`, `values.schema.json`, `README.md`, `scripts/install.sh`, and `templates/`. Put other chart files in their own folder, for example `dashboards/` and `alerts/` for Grafana, and load them with `.Files.Get` or `.Files.Glob`. Do not put them loose in the chart root or `templates/`.
2. **One file per resource.** Name each template after its kind in lowercase: `deployment.yaml`, `statefulset.yaml`, `service.yaml`, `ingress.yaml`, `configmap.yaml`, `serviceaccount.yaml`, `clusterrole.yaml`, `clusterrolebinding.yaml`, `ingressclass.yaml`. Shared named templates go in `_helpers.tpl`. Several resources of the same kind, such as the platform NetworkPolicies, may share one file.
3. **Validation in each template.** Start every template with `required` checks for the values that file uses. Check the parent before the child, use `$_` and the full path, and do not use named variables for validation:
   ```gotemplate
   {{- $_ := required "image settings are required" .Values.image -}}
   {{- $_ := required "image.repository is required" .Values.image.repository -}}
   ```
   Use `fail` for rules such as postgres's `replicaCount must be 1`. Named variables are fine for values reused in the body, as in `platform/templates/network-policies.yaml`.
4. **Defaults and schema.** `values.yaml` holds every default the chart needs. Profile overlays (`helm/deployment/<env>/<cluster>/<chart>/values.yaml`) contain only what differs for that cluster, and may be empty. Update `values.schema.json` in the same change: types, `required`, and `additionalProperties: false` where the chart already uses it.
5. **No credentials in values.** Values hold only `existingSecret` and the key names. `scripts/install.sh` creates the Secret with `kubectl create secret` only if it is missing, never overwrites it, and prints a generated login once if the user needs one.
6. **`scripts/install.sh` contract.** Use `set -euo pipefail` and find the chart with `chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"`.
   - Check the required commands. Check that the namespace exists: platform owns the namespaces, so never use `--create-namespace`.
   - Create the chart's Secrets. If `Chart.yaml` has dependencies, run `helm repo add` and `helm dependency update` here.
   - End with `helm upgrade --install <release> "$chart_dir" --namespace <ns> "$@"`. Keep the script executable and compatible with bash 3.2.
7. **Ports and security.** Use unprivileged ports: HTTP apps on 8080, pgAdmin on 5050, and Traefik on 8080/8443. Do not use port 80. Do not add `NET_BIND_SERVICE` for ports; add it only when the image binary has it as a file capability (caddy does: without it, exec fails with "operation not permitted"). Drop all capabilities and run as non-root.
8. **Network policy.** Pods use `app.kubernetes.io/name: <chart>`. A new workload in a policed namespace needs a matching rule and selector in the platform chart.
9. **README.** Keep it short: what the chart does, how to install it, Secrets, a values table, and the list of templates. Mark scaffolds as such.
10. **Deploying it.** Add the chart to the profile's `deploy-set.json` in dependency order. Do this only when the chart is implemented, and add an overlay folder only if values differ. Update `helm/charts/README.md` if the profile's chart list changes.
11. **Verify.** Run `helm lint helm/charts/<chart> --values <profile>/<chart>/values.yaml` and `helm template` with the same values. Do not deploy unless the user asks.

## Deployment profiles

- `helm/deployment/<env>/<cluster>/` contains only `deploy-set.json`, `deploy.sh`, `install.sh`, `README.md`, and one `<chart>/values.yaml` overlay per chart. Put new profile logic into `install.sh` or `deploy.sh`; do not add more helper scripts. Files the scripts generate (such as `.local/<cluster>.kubeconfig`) go under the directory the script is run from.
- `install.sh <user@host>` (default: SSH) bundles `helm/charts` and the profile, copies it to the node, and runs `deploy.sh --local` there. A local mode is planned, not implemented.
- `deploy.sh <user@host>` (default: remote) fetches the node's kubeconfig over SSH into `.local/<cluster>.kubeconfig`, renames its context to the cluster name (the profile folder name), and runs Helm from the Mac. `--kubeconfig <user@host>` only refreshes that file (for k9s), and `--local` uses the current context.
- `deploy-set.json` has `defaults.helmArgs` and an ordered `releases` list. Each entry is `{ "chart": "...", "helmArgs": [...], "values": "..." }`; only `chart` is required.
- `deploy.sh` reads that file and runs each `helm/charts/<chart>/scripts/install.sh`. It differs per profile and needs `jq`.
- Other profiles are separate targets. Never deploy them automatically.

## Before changing a cluster

1. Read the profile README and `AGENTS.md`.
2. Inspect `kubectl config current-context`, cluster nodes, and relevant Helm releases before applying changes.
3. For commands from the Mac, use `.local/<cluster>.kubeconfig` (written by `deploy.sh`) explicitly. Do not rewrite or clean the user's global kubeconfig, and do not deploy this profile to Docker Desktop, AKS, or another context.
4. Use the profile installer, which follows its `deploy-set.json`, or run a single chart with `helm/charts/<chart>/scripts/install.sh --values <profile>/<chart>/values.yaml`. Keep generated secrets in Kubernetes Secrets; never commit them or place them in Helm values.

## Troubleshooting layers

Check the request path one layer at a time:

1. DNS/hosts resolution maps the requested hostname to the VM address; Kubernetes Ingress does not create that mapping.
2. Traefik listens on host ports 8080/8443. Check the Ingress class, host, path, backend Service, and ready endpoints.
3. Confirm the URL scheme and port match the entrypoint (`http://<host>:8080/`). The UTM profile serves routes over HTTP; HTTPS needs TLS configuration and a certificate trusted by the client.
4. Check the application pod and logs only after the request has reached the correct Ingress route.

For a temporary HTTP check without changing DNS, follow the profile README's `curl --resolve` examples. A Traefik 404 usually means no route matched the Host/path/entrypoint; it does not by itself prove the application is down. A browser DNS NXDOMAIN means resolution failed before Kubernetes was reached.

## Storage and app relationships

- The UTM profile's `homelab-pvc-storage` class maps to MicroK8s hostpath storage and is created by the platform chart from the profile overlay. A PVC stuck with "storageclass not found" usually means the platform overlay was not applied.
- PostgreSQL is the database backend, PgBouncer is its connection pooler, and pgAdmin is a browser client. Verify each service and namespace rather than treating the stack as a single release.
- Keep replicas at one for the current single-node learning environment unless the user explicitly chooses a different topology.
