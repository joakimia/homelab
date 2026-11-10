domain         = "joakimia.dev"
tunnel_name    = "homelab-rke2-cluster-dev"
origin_service = "https://traefik.hlab-networking.svc.cluster.local:8443"
# authentik: it has its own login, and apps call its OIDC endpoints without a browser.
public_hosts = ["homepage", "authentik"]
# https://joakimia.dev/ shows the homepage (its Ingress has joakimia.dev as an extra host).
public_apex = true
