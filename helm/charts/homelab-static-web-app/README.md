# Homelab static web app chart

Base chart for a static website: Caddy serves files from the values or from an existing ConfigMap, published through Traefik at `https://<host>:8443/`. The [`homelab`](../homelab/README.md) chart uses it for the homepage (alias `homelab-frontend`); another site is one more alias there.

## Install

Normally included by the `homelab` chart. As its own release: `./scripts/install.sh <release> --values <app values> --wait`. The values must set at least `name`, `host`, and `files` or `filesConfigMap`. Changed files reach Caddy within about a minute (the ConfigMap is mounted as a directory), without a restart. No Secrets are needed.

## Values

| Value | Default | Purpose |
|---|---|---|
| `namespace` | `hlab-frontend-apps` | Namespace of the resources (Traefik may reach every pod there). |
| `name` / `host` | required | Resource names and `app.kubernetes.io/name`; Ingress hostname. |
| `filesConfigMap` | `""` | Existing ConfigMap with the site files (one key per file), for example from a parent chart's own folder; then `files` is not used. |
| `files` | placeholder `index.html` | File name → content, when `filesConfigMap` is empty. Flat names only. |
| `ingress.className` | `traefik` | IngressClass of the Ingress. |
| `ingress.tls.enabled` / `clusterIssuer` | `true` / `homelab-ca` | HTTPS with a cert-manager certificate (`<name>-tls`). |
| `ingress.auth.enabled` / `middleware` | `false` / `authelia@file` | Login through Authelia; the route is then HTTPS only. |
| `ingress.catchAll` | `false` | Also answer requests without a matching host (`http://<node-ip>:8080/`); one app per cluster, and not together with `ingress.auth`. |
| `service.port` / `containerPort` | `8080` / `8080` | Service and Caddy port. |
| `probes.*` | `httpGet /` | Startup, readiness, and liveness probes. |
| `securityContext` | non-root, `NET_BIND_SERVICE` | The caddy binary carries that file capability; exec fails without it. |

## Templates

`configmap.yaml` (Caddyfile, and the files when they come from the values), `deployment.yaml`, `service.yaml`, `ingress.yaml`.
