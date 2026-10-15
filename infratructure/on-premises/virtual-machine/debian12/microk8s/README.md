# MicroK8s on Debian 12 in UTM

NoCloud seeds that turn a fresh Debian 12 VM into a MicroK8s node for the local learning cluster. Provision with the shared [`../install.sh`](../README.md):

```sh
# from infratructure/on-premises/virtual-machine/debian12/
./install.sh microk8s control-plane-node debian@<vm-ip>    # hostname homelab-cp0
./install.sh --join debian@<cp0-ip> microk8s worker-node debian@<vm-ip> homelab-wk0
```

Each node is a cluster of its own until it joins one; see [Join nodes to a cluster](#join-nodes-to-a-cluster).

## What the seed does

Updates Debian, installs the tools below, and adds `debian` to the `microk8s` group. On the control plane it also writes `~/.kube/config` and enables hostpath storage and metrics-server (`kubectl top`, k9s CPU/MEM columns). On a VM provisioned before that, run `sudo microk8s enable metrics-server` once. For Longhorn it installs `open-iscsi` and `nfs-common`, loads `iscsi_tcp` (now and at boot), and starts `iscsid`; on an older VM, run the commands under [Longhorn on an existing VM](#longhorn-on-an-existing-vm). The last steps apply the [basic hardening](../README.md#basic-hardening-work-in-progress).

| Tool | Pin |
|---|---|
| MicroK8s | snap track `1.36/stable` (patch updates through snap refresh) |
| kubectl (control plane) | snap track `1.36/stable`, same minor as MicroK8s |
| Helm (control plane) | `v4.3.0` from `get.helm.sh`, SHA-256 checked |
| k9s (control plane) | `v0.51.0` from GitHub, SHA-256 checked |
| jq, curl, open-iscsi, nfs-common | Debian 12 packages |

To upgrade, change the MicroK8s track in both `cloud-init.yaml` files (nodes in one cluster run the same minor) and the other pins in the control plane's. For Helm and k9s, also update the `amd64` and `arm64` checksums from the release.

## Check the result

On the VM, after logging in again (so the `microk8s` group applies):

```sh
cloud-init status --long          # log: /var/log/cloud-init-output.log
microk8s status --wait-ready
kubectl get nodes                 # control plane only, like Helm and k9s
helm version && k9s version
```

## Join nodes to a cluster

`--join debian@<cp-ip>` provisions a node and joins it to the cluster of that control plane; `--join-only` joins a node provisioned earlier. A `worker-node` joins with `--worker` (kubelet and workloads only); a `control-plane-node` joins as another control plane, and its `~/.kube/config` is written again with the cluster's credentials. The script:

1. adds the two nodes to each other's `/etc/hosts` (MicroK8s refuses a join when the node's hostname does not resolve to its IP);
2. runs `microk8s add-node --token-ttl 600` on the control plane for a one-time token, which is passed through files, never as an argument;
3. runs `microk8s join` on the new node and waits until it is `Ready`.

A rerun skips the join when the node is already in the cluster. Things to watch out for:

- Node names must be unique (`homelab-wk0`, `homelab-wk1`, ...). Pass the hostname to `install.sh`.
- The nodes reach each other by IP. If DHCP gives the control plane a new address, the other nodes lose it.
- UTM with the Apple Virtualization backend: in **Shared** network mode the VMs reach the Mac but not each other, so the join fails with `No route to host`. Use **Bridged** for every node; they then get addresses from the LAN router.
- Only the new node and the control plane it joins through get `/etc/hosts` entries for each other; other nodes do not.
- MicroK8s needs three control planes for high availability; with two, losing either stops the cluster.
- `microk8s-hostpath` volumes live on one node, and Traefik's host ports follow the pod. Pin those workloads to a node in the profile before adding workers.

Check on the control plane: `kubectl get nodes -o wide`. To remove a worker: `microk8s leave` on it, then `microk8s remove-node <name>` on the control plane.

## Longhorn on an existing VM

A VM provisioned before the seed had the Longhorn prerequisites needs them once:

```sh
sudo apt-get install -y open-iscsi nfs-common
echo iscsi_tcp | sudo tee /etc/modules-load.d/longhorn.conf
sudo modprobe iscsi_tcp
sudo systemctl enable --now iscsid
```

Longhorn needs memory too: give the VM at least 8 GB in UTM before deploying it.

Then deploy the charts with the [UTM Helm profile](../../../../../helm/deployment/dev/local-microk8s-cluster-dev/README.md).
