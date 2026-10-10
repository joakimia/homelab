# Homelab

A personal homelab repository focused on learning and building the infrastructure, DevOps, and CI/CD foundations behind a homelab. It covers the underlying platform features and Kubernetes workload deployment patterns. Homelab applications are hosted privately in the lab and generally live in their own repositories, with their own pipelines and Helm charts; this repository documents the shared infrastructure and repeatable deployment structure they build on.

The current development environment is a Debian 12 virtual machine in UTM running MicroK8s. Its `192.168.64.x` addressing and local networking notes apply only to that UTM setup. Running RKE2 on dedicated hardware is a later goal and will use network, address, and DNS choices suited to the home LAN.

## Current focus

1. Provision the Debian VM from a NoCloud cloud-init seed.
2. Verify MicroK8s, Helm, kubectl, and k9s on the VM.
3. Deploy the development Helm profile in `helm/deployment/dev/mac-utm-k3s-cluster` and check access through Traefik.

The repository is under active development. The UTM profile is the first working target; other charts and deployment profiles may still be scaffolds.

## Where things live

- `infratructure/on-premises/debian12/microk8s/` — cloud-init seed generation and Debian provisioning helpers.
- `helm/charts/` — individual Helm charts.
- `helm/deployment/` — environment-specific groups of charts and install scripts.
- `docs/` — architecture notes, user guides, and operational runbooks.
- `tests/` — validation work as it is added.

Start with the [MicroK8s provisioning guide](infratructure/on-premises/debian12/microk8s/README.md), then see the [UTM development deployment](helm/deployment/dev/mac-utm-k3s-cluster/README.md).
