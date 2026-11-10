# DevOps

How the homelab is operated once the infrastructure exists. **Work in progress.**

| Folder | What it covers |
|---|---|
| [`argo-cd/`](argo-cd/README.md) | GitOps: how Argo CD keeps the RKE2 cluster in sync with this repository, and how to deploy a branch. |
| [`ansible/`](ansible/README.md) | The Proxmox host: pinned tools (Helm, kubectl, OpenTofu) for `deploy.sh --local`. |

Related: the Cloudflare edge is OpenTofu in [`infratructure/cloudflare`](../infratructure/cloudflare/README.md) (CD in `.github/workflows/cd.yml`), and the VMs are cloud-init seeds in [`infratructure/on-premises`](../infratructure/on-premises/virtual-machine/debian13/README.md).
