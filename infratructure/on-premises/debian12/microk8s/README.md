# MicroK8s on Debian 12 in UTM

NoCloud seeds that turn a fresh Debian 12 VM into a MicroK8s node for the local learning cluster. Provision with the shared [`../install.sh`](../README.md):

```sh
# from infratructure/on-premises/debian12/
./install.sh microk8s control-plane-node debian@<vm-ip>    # hostname homelab-cp0
```

`worker-node/cloud-init.yaml` is work in progress: the worker does not join the cluster yet.

## What the seed does

Updates Debian, installs the tools below, adds `debian` to the `microk8s` group, and writes `~/.kube/config`. On the control plane it also enables hostpath storage.

| Tool | Pin |
|---|---|
| MicroK8s | snap track `1.36/stable` (patch updates through snap refresh) |
| kubectl | snap track `1.36/stable`, same minor as MicroK8s |
| Helm | `v4.3.0` from `get.helm.sh`, SHA-256 checked |
| k9s | `v0.51.0` from GitHub, SHA-256 checked |
| jq, curl | Debian 12 packages |

To upgrade, change the versions in both `cloud-init.yaml` files. For Helm and k9s, also update the `amd64` and `arm64` checksums from the release.

## Check the result

On the VM, after logging in again (so the `microk8s` group applies):

```sh
cloud-init status --long          # log: /var/log/cloud-init-output.log
microk8s status --wait-ready
kubectl get nodes
helm version && k9s version
```

Then deploy the charts with the [UTM Helm profile](../../../../helm/deployment/dev/mac-utm-microk8s-cluster/README.md).
