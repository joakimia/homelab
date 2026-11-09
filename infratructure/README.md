# Infrastructure

Provisioning that runs before Helm: turning a fresh machine or VM into a Kubernetes node. Start with [on-premises/virtual-machine/debian13/README.md](on-premises/virtual-machine/debian13/README.md). Once a node is ready, deploy the charts from `helm/deployment/`.

[ansible/README.md](ansible/README.md) prepares the Proxmox host that deploys the RKE2 profile (work in progress).
