# Traefik chart

Runs Traefik as the Ingress controller in `hlab-networking`. It watches Kubernetes `Ingress` resources with `ingressClassName: traefik` and listens on host ports **8080** (HTTP) and **8443** on the node, so URLs include the port, for example `https://homepage.homelab.com:8443/`. Its dashboard/ping entrypoint uses 9000 inside the pod only. The ports are unprivileged, so the container needs no added capabilities.

## Install

Normally installed by the cluster profile's `deploy.sh` after `platform`. To install it alone:

```sh
./scripts/install.sh --values ../../deployment/dev/local-microk8s-cluster-dev/traefik/values.yaml --wait
```

No Secrets are needed. Every route is served on both entrypoints; on 8443 with the certificate from the Ingress `spec.tls` Secret, or Traefik's self-signed default.

## Values

| Value | Default | Purpose |
|---|---|---|
| `ports.web` | `8080` / host `8080` | HTTP entrypoint; `hostPort` is optional. |
| `ports.websecure` | `8443` / host `8443` | HTTPS entrypoint (`--entrypoints.websecure.http.tls=true`). |
| `forwardAuth.enabled` / `address` | `true` / Authelia Service | Middleware `authelia@file` (file provider), used by Ingresses with `ingress.auth.enabled`. |
| `ports.traefik.containerPort` | `9000` | Dashboard and `/ping` (probes), not exposed. |
| `service.type` / `ports.web` / `ports.websecure` | `ClusterIP` / `8080` / `8443` | Service for web and websecure. With a load balancer: `LoadBalancer`, `80`/`443`, no `hostPort`s. |
| `name` | `traefik` | Name of the Deployment, Service, and RBAC objects, and the `app.kubernetes.io/name` label. |
| `ingress.className` / `isDefaultClass` | `traefik` / `false` | IngressClass created by the chart. |
| `probes.*` | `httpGet /ping` | Startup, readiness, and liveness probes. |
| `replicaCount` | `1` | One replica per node; host ports can only be bound once per node. |


## Templates

`serviceaccount.yaml`, `clusterrole.yaml`, `clusterrolebinding.yaml`, `ingressclass.yaml`, `deployment.yaml`, `service.yaml`, `_helpers.tpl`.
