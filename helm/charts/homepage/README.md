# Homepage chart

Serves a small HTML page with Caddy in `hlab-frontend-apps`, published through Traefik at `http://homepage.homelab.com:8080/`. It also has a hostless rule, so `http://<VM-IP>:8080/` opens it directly.

## Install

Normally installed by the cluster profile's `deploy.sh`. To install it alone:

```sh
./scripts/install.sh --values ../../deployment/dev/mac-utm-microk8s-cluster/homepage/values.yaml --wait
```

No Secrets are needed.

## Values

| Value | Default | Purpose |
|---|---|---|
| `host` | `homepage.homelab.com` | Ingress hostname. |
| `service.port` / `containerPort` | `8080` / `8080` | Service and Caddy port. |
| `content` | small HTML page | Served as `index.html`. |

## Templates

`configmap.yaml` (Caddyfile and page), `deployment.yaml`, `service.yaml`, `ingress.yaml`.
