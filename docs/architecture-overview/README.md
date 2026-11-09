# Architecture overview

How the homelab components fit together.

- [RKE2 development cluster](homelab-rke2-cluster-dev/README.md): two Debian 13 VMs on Proxmox, published through a Cloudflare Tunnel, deployed by Argo CD.
- The UTM MicroK8s cluster is described in its [profile guide](../../helm/deployment/dev/local-microk8s-cluster-dev/README.md).

Drawing sources (Excalidraw, still empty): [`local-microk8s-cluster-dev/`](local-microk8s-cluster-dev/EXCALIDRAW.md) and [`homelab-rke2-cluster-dev/`](homelab-rke2-cluster-dev/EXCALIDRAW.md).
