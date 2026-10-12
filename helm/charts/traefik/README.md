# Traefik chart

Runs Traefik as the Ingress controller in `hlab-networking`. It watches Kubernetes `Ingress` resources with `ingressClassName: traefik` and listens on host ports **8080** (HTTP) and **8443** on the node, so URLs include the port, for example `http://homepage.homelab.com:8080/`. Its dashboard/ping entrypoint uses 9000 inside the pod only. The ports are unprivileged, so the container needs no added capabilities.

## Install

Normally installed by the cluster profile's `deploy.sh` after `platform`. To install it alone:

```sh
./scripts/install.sh --values ../../deployment/dev/local-microk8s-cluster-dev/traefik/values.yaml --wait
```

No Secrets are needed. TLS certificates and DNS are not configured; the local routes are HTTP only.

## Values

| Value | Default | Purpose |
|---|---|---|
| `ports.web` | `8080` / host `8080` | HTTP entrypoint. |
| `ports.websecure` | `8443` / host `8443` | HTTPS entrypoint (no certificates yet). |
| `ports.api.containerPort` | `9000` | Dashboard and ping, not exposed. |
| `ingressClass.name` / `isDefaultClass` | `traefik` / `false` | IngressClass created by the chart. |
| `replicaCount` | `1` | One replica per node; host ports can only be bound once per node. |

If you change the web/websecure ports, update `networkPolicies.traefik.ports` in the platform chart too.

## Templates

`serviceaccount.yaml`, `clusterrole.yaml`, `clusterrolebinding.yaml`, `ingressclass.yaml`, `deployment.yaml`, `service.yaml`, `_helpers.tpl`.
