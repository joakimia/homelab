# Homepage chart

Serves the configurable `content` value with Caddy and exposes it through a Traefik Ingress. Defaults to one replica at `homepage.homelab.com` in `hlab-frontend-apps`; set `replicaCount` to scale it.

No environment variables or Secrets are required. The host name must resolve to a node IP running Traefik.
