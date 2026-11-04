# On-premises nodes

Provisioning for Kubernetes nodes on Debian 13, with cloud-init over SSH. See [debian13/README.md](virtual-machine/debian13/README.md).

- `debian13/microk8s/`: the current UTM learning cluster.
- `debian13/rke2/`: the deployed Proxmox development cluster.
- `debian13/jumpbox/`: work in progress. The entry point outside the cluster, with tools, the provisioning bundle, and a local registry.
