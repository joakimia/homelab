# Homelab

A personal hobby and learning project: a small Kubernetes lab at home, built from code to learn Linux, cloud-init, Kubernetes, Helm, GitOps, and infrastructure automation. It is not production-ready. Applications generally live in their own repositories; this one holds the shared infrastructure and the deployment structure they build on.

## What runs today

The development cluster runs **RKE2 on two Debian 13 VMs on a Proxmox host** (`homelab-k8s-node-cp0` and `homelab-k8s-node-wk0`), published as **`*.joakimia.dev`** through a Cloudflare Tunnel:

```text
Browser ─▶ Cloudflare (TLS, Access login) ─▶ Tunnel ─▶ cloudflared ─▶ Traefik ─▶ apps
                                              (outbound from the cluster; no open ports at home)

merge to main ─▶ GitHub ◀── Argo CD (in the cluster) syncs the RKE2 profile
```

| Layer | What | Where |
|---|---|---|
| Edge | Cloudflare Tunnel, wildcard DNS, Access login (all hosts except the homepage and Authentik), DNS-01 token | [`infratructure/cloudflare`](infratructure/cloudflare/README.md) (OpenTofu) |
| Nodes | Debian 13 VMs from cloud-init seeds; RKE2 (Proxmox) or MicroK8s (UTM) | [`infratructure/on-premises`](infratructure/on-premises/virtual-machine/debian13/README.md) |
| Platform | Namespaces and NetworkPolicies, cert-manager with Let's Encrypt, Traefik, Longhorn, local-path storage | [`helm/charts`](helm/charts/README.md) |
| Apps | PostgreSQL, PgBouncer, pgAdmin, Authentik, the homepage, Prometheus, Loki, Tempo, Alloy, Grafana | [`helm/charts`](helm/charts/README.md) |
| Delivery | Argo CD deploys the profile from `main`; Ansible prepares the Proxmox host; CI runs `tests/check.sh` | [`devops`](devops/README.md) |

Start with the [RKE2 profile guide](helm/deployment/dev/homelab-rke2-cluster-dev/README.md) and the [architecture overview](docs/architecture-overview/homelab-rke2-cluster-dev/README.md). The UTM MicroK8s profile ([guide](helm/deployment/dev/local-microk8s-cluster-dev/README.md)) stays available for local learning. A prod environment on `joakimia.com` is planned, not started.

## Where things live

The repository is split by question:

- **`infratructure/`: what exists.** Cloud-init seeds and the provisioning `install.sh` for the VMs, OpenTofu for Cloudflare, and Azure Bicep (experiments).
- **`helm/`: what runs in a cluster.** `charts/` holds every chart; `deployment/<env>/<cluster>/` is a cluster profile that picks charts and overlays. [README](helm/README.md)
- **`devops/`: how it gets deployed and operated.** The Argo CD (GitOps) flow and Ansible for the Proxmox host. [README](devops/README.md)
- **`docs/`:** architecture notes, user guides, and runbooks. [README](docs/README.md)
- **`tests/`:** `check.sh`, the static and Docker checks CI runs, with test cases that mirror the code. [README](tests/README.md)

## Status

| Part | State |
|---|---|
| RKE2 cluster on Proxmox, all charts in the profile | Deployed, managed by Argo CD from `main` |
| Cloudflare (dev) | Applied; state in R2, CD (`cd.yml`) applies on merge to `main` |
| Ansible for the Proxmox host | Run against the host on 2026-11-09 (Helm, kubectl, OpenTofu pinned); tested in CI on `debian:13` |
| UTM MicroK8s profile | Works; addresses change with the Mac's LAN |
| Jumpbox seed, several charts (`kafka`, `rabbitmq`, `stalwart-mail`, …) | Scaffolds or work in progress |

Versions are pinned throughout (charts in `Chart.lock`, tools in `mise.toml` and the seeds). Run `tests/check.sh` before pushing.
