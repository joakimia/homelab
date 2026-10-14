# Homepage chart

Serves a small HTML page with Caddy in `hlab-frontend-apps`, published through Traefik at `https://homepage.homelab.com:8443/` (and `http://homepage.homelab.com:8080/`). It also has a hostless rule, so `http://<VM-IP>:8080/` opens it directly.

## Install

Normally installed by the cluster profile's `deploy.sh`. To install it alone:

```sh
./scripts/install.sh --values ../../deployment/dev/local-microk8s-cluster-dev/homepage/values.yaml --wait
```

No Secrets are needed.

## Values

| Value | Default | Purpose |
|---|---|---|
| `ingress.className` | `traefik` | IngressClass of the Ingress. |
| `ingress.tls.enabled` / `clusterIssuer` | `true` / `homelab-ca` | HTTPS with a cert-manager certificate (`<name>-tls`). |
| `ingress.auth.enabled` / `middleware` | `false` / `authelia@file` | Login through Authelia; the route is then HTTPS only. |
| `host` | `homepage.homelab.com` | Ingress hostname. |
| `service.port` / `containerPort` | `8080` / `8080` | Service and Caddy port. |
| `probes.*` | `httpGet /` | Startup, readiness, and liveness probes. |
| `content` | small HTML page | Served as `index.html`. |

## Templates

`configmap.yaml` (Caddyfile and page), `deployment.yaml`, `service.yaml`, `ingress.yaml`.
