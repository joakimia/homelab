# argo-cd chart

Runs [Argo CD](https://argo-cd.readthedocs.io/) in `hlab-gitops`, from the upstream Argo Helm chart pinned in `Chart.lock` (chart 10.17.1, Argo CD v3.6.1). Argo CD keeps the cluster in sync with this Git repository. The Applications come from the [`argo-cd-apps`](../argo-cd-apps/README.md) chart, which is installed after this one because it needs the CRDs.

## Install

Normally installed by the cluster profile's `deploy.sh` (last in `deploy-set.json`, before `argo-cd-apps`). To install it alone:

```sh
helm/charts/argo-cd/scripts/install.sh --values helm/deployment/dev/homelab-rke2-cluster-dev/argo-cd/values.yaml --wait
```

## Login

The UI is at `https://<host>/`, behind Cloudflare Access in the RKE2 profile. Log in as `admin`. Argo CD creates the password on first start:

```sh
kubectl -n hlab-gitops get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode
```

Change it in the UI (User Info → Update password), then delete `argocd-initial-admin-secret`.

## How it fits the profiles

- The server speaks plain HTTP (`server.insecure`); Traefik terminates TLS with this chart's own Ingress.
- Resources are tracked by annotation, so Argo CD adopts what `deploy.sh` (Helm) installed earlier.
- Ingresses count as healthy once they exist: Traefik uses host ports and publishes no load balancer address, which Argo CD would otherwise show as Progressing forever.
- Argo CD runs `helm dependency build` itself. HTTPS Helm repositories must be listed in `argo-cd.configs.repositories` (`tests/check.sh charts` checks this); OCI repositories need no entry.
- Argo CD renders charts with `helm template`, so `lookup` returns nothing. The charts' Secret checks are skipped, and Secrets are still created by the install scripts (`deploy.sh` once per cluster).

## Values

| Value | Default | Purpose |
|---|---|---|
| `host` | `argocd.homelab.com` | UI hostname. |
| `ingress.tls.clusterIssuer` | `homelab-ca` | Certificate issuer. |
| `ingress.backend` | `argocd-server:80` | Service the Ingress points to. |
| `argo-cd.configs.repositories` | Longhorn, Grafana | HTTPS Helm repositories the charts depend on. |
| `argo-cd.*` | see `values.yaml` | Upstream values ([chart docs](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd)); Dex and notifications are off. |

## Templates

`ingress.yaml`; the rest comes from the upstream chart.
