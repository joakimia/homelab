# Homelab

A personal homelab repository focused on learning and building the infrastructure, DevOps, and CI/CD foundations behind a homelab. It covers the underlying platform features and Kubernetes workload deployment patterns. Homelab applications are hosted privately in the lab and generally live in their own repositories, with their own pipelines and Helm charts; this repository documents the shared infrastructure and repeatable deployment structure they build on.

The homelab has two Debian 13 environments: a MicroK8s learning cluster in UTM, and a two-node RKE2 development cluster on Proxmox (`homelab-k8s-node-cp0` and `homelab-k8s-node-wk0`). UTM addressing is separate from the home LAN setup used by Proxmox.

## Current focus

The active development cluster runs RKE2 on Proxmox. Its nodes use `10.10.10.101` and `10.10.10.102`; the deployment and access steps are in the [RKE2 profile guide](helm/deployment/dev/homelab-rke2-cluster-dev/README.md). The UTM MicroK8s profile remains available for local learning:

```sh
infratructure/on-premises/virtual-machine/debian13/install.sh microk8s control-plane-node debian@<vm-ip>
helm/deployment/dev/local-microk8s-cluster-dev/install.sh debian@<vm-ip>
```

The RKE2 seed and profile have been deployed and verified on the Proxmox VMs. The jumpbox seed and some charts remain work in progress or scaffolds.

## Where things live

- `infratructure/on-premises/virtual-machine/debian13/`: the shared `install.sh` and cloud-init seeds for MicroK8s, RKE2, and the jumpbox. [README](infratructure/on-premises/virtual-machine/debian13/README.md)
- `helm/charts/`: individual Helm charts. [README](helm/charts/README.md)
- `helm/deployment/`: cluster profiles that choose and deploy charts. [README](helm/README.md)
- `docs/`: architecture notes, user guides, and runbooks.
- `tests/`: `check.sh` with the static checks that CI also runs. [README](tests/README.md)
