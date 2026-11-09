# RKE2 development cluster

How the Proxmox cluster fits together. Profile and commands: [RKE2 profile guide](../../../helm/deployment/dev/homelab-rke2-cluster-dev/README.md).

## Machines

```text
Proxmox host (homelab-server-0, reached from the Mac over Tailscale: ssh homelab)
├─ homelab-k8s-node-cp0  10.10.10.101  RKE2 server (API, etcd) + workloads
└─ homelab-k8s-node-wk0  10.10.10.102  RKE2 agent + workloads
```

- The VMs come from the RKE2 cloud-init seed; the Proxmox host has helm, kubectl, and the kubeconfig (`homelab-server` context), prepared by Ansible.
- Storage: `homelab-pvc-storage` is node-local (local-path-provisioner); Longhorn replicates volumes across both nodes for data that must survive one node.

## Request path

```text
Browser ─HTTPS─▶ Cloudflare edge ─▶ Access login ─▶ Tunnel ─▶ cloudflared (2 pods, hlab-networking)
                 *.joakimia.dev      (not for the     (outbound   │
                 certificate          homepage or     from the    ▼ HTTPS, SNI = requested host
                                      Authentik)      cluster)  Traefik :8443 ─▶ Ingress ─▶ app
```

- DNS: `*.joakimia.dev` and `joakimia.dev` are proxied CNAMEs to the tunnel, so every client, also on the home LAN, goes through Cloudflare.
- TLS twice: Cloudflare's edge certificate for the browser, and a Let's Encrypt certificate per Ingress (cert-manager, DNS-01 through Cloudflare) that cloudflared verifies.
- Logins: Cloudflare Access (one-time PIN by email) in front of the UIs; Grafana, pgAdmin, Argo CD, and Authentik also have their own.

## Delivery

```text
PR ─▶ CI (tests/check.sh) ─▶ merge to main ─▶ Argo CD (hlab-gitops) polls GitHub
                                              └─ ApplicationSet: one Application per release
                                                 in deploy-set.json, synced with selfHeal
```

- Bootstrap: the first `deploy.sh` run installs every chart with Helm and creates the Secrets; Argo CD then adopts the releases.
- A branch can be deployed before merging with `deploy.sh --revision <branch>`; see [devops/argo-cd](../../../devops/argo-cd/README.md).
- Cloudflare changes go through OpenTofu (`cd.yml`: plan on PR, apply on main).

## Namespaces

| Namespace | What runs there |
|---|---|
| `hlab-networking` | Traefik, cloudflared |
| `hlab-platform` | cert-manager, issuers, Authentik |
| `hlab-database` | PostgreSQL, PgBouncer |
| `hlab-frontend-apps` | homepage, pgAdmin |
| `hlab-observability` (+ `-agents`) | Prometheus, Loki, Tempo, Alloy, Grafana (node-exporter) |
| `hlab-storage`, `hlab-filestore` | Longhorn, local-path-provisioner, the shared claim |
| `hlab-gitops` | Argo CD |
| `hlab-tools` | the daily cleanup job |

The platform chart creates them with Pod Security levels and default-deny NetworkPolicies where the workloads allow it ([platform chart](../../../helm/charts/platform/README.md)).
