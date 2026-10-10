# Homelab

A personal homelab repository for learning infrastructure, Kubernetes, and deployment automation. The initial environment is a Debian 12 virtual machine in UTM running MicroK8s; a later goal is to run RKE2 on dedicated hardware.

## Current focus

1. Provision the Debian VM from a NoCloud cloud-init seed.
2. Verify MicroK8s, Helm, kubectl, and k9s on the VM.
3. Deploy the development Helm profile in `helm/deployment/dev/mac-utm-k3s-cluster` and check access through Traefik.

The repository is under active development. The UTM profile is the first working target; other charts and deployment profiles may still be scaffolds.

## Where things live

- `hosting-infratructure/on-premises/debian12/microk8s/` — cloud-init seed generation and Debian provisioning helpers.
- `helm/charts/` — individual Helm charts.
- `helm/deployment/` — environment-specific groups of charts and install scripts.
- `docs/` — architecture notes, user guides, and operational runbooks.
- `tests/` — validation work as it is added.

Start with the [MicroK8s provisioning guide](hosting-infratructure/on-premises/debian12/microk8s/README.md), then see the [UTM development deployment](helm/deployment/dev/mac-utm-k3s-cluster/README.md).
