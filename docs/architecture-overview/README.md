# Architecture overview

This section records how the homelab components fit together. The architecture is evolving as the UTM and MicroK8s setup is verified.

Current starting point: a Debian 12 VM in UTM runs MicroK8s; Helm deployment profiles install workloads into that cluster. RKE2 on dedicated hardware is a future target.

The [`EXCALIDRAW.md`](EXCALIDRAW.md) file is the current architecture drawing source.
