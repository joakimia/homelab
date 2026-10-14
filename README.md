# Homelab

A personal homelab repository focused on learning and building the infrastructure, DevOps, and CI/CD foundations behind a homelab. It covers the underlying platform features and Kubernetes workload deployment patterns. Homelab applications are hosted privately in the lab and generally live in their own repositories, with their own pipelines and Helm charts; this repository documents the shared infrastructure and repeatable deployment structure they build on.

The current development environment is a Debian 12 virtual machine in UTM running MicroK8s. Its `192.168.64.x` addressing and local networking notes apply only to that UTM setup. Running RKE2 on dedicated hardware is a later goal and will use network, address, and DNS choices suited to the home LAN.

## Current focus

Provision a Debian 12 VM in UTM with cloud-init, then deploy the development Helm profile and reach it through Traefik:

```sh
infratructure/on-premises/debian12/install.sh microk8s control-plane-node debian@<vm-ip>
helm/deployment/dev/local-microk8s-cluster-dev/install.sh debian@<vm-ip>
```

The UTM profile is the first working target. RKE2 seeds, the jumpbox, and many charts are still work in progress or scaffolds.

## Where things live

- `infratructure/on-premises/debian12/`: the shared `install.sh` and cloud-init seeds for MicroK8s, RKE2, and the jumpbox. [README](infratructure/on-premises/debian12/README.md)
- `helm/charts/`: individual Helm charts. [README](helm/charts/README.md)
- `helm/deployment/`: cluster profiles that choose and deploy charts. [README](helm/README.md)
- `docs/`: architecture notes, user guides, and runbooks.
- `tests/`: `check.sh` with the static checks that CI also runs. [README](tests/README.md)
