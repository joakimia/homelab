# Architecture overview

This section records how the homelab components fit together. The architecture is evolving as the UTM and MicroK8s setup is verified.

Current starting point: a Debian 12 VM in UTM runs MicroK8s; Helm deployment profiles install workloads into that cluster. RKE2 on dedicated hardware is a future target.

Drawing sources (Excalidraw, still empty): [`local-microk8s-cluster-dev/`](local-microk8s-cluster-dev/EXCALIDRAW.md) and [`homelab-rke2-cluster-dev/`](homelab-rke2-cluster-dev/EXCALIDRAW.md).
