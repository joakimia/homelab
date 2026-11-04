# RKE2 on Debian 13

These seeds provision the Debian 13 RKE2 development cluster on Proxmox. The control plane is `homelab-k8s-node-cp0` (`10.10.10.101`) and the worker is `homelab-k8s-node-wk0` (`10.10.10.102`). Both nodes and the Helm profile have been deployed and verified.

## What the control-plane seed does

- Updates Debian and installs `curl` and `jq`, plus `open-iscsi` and `nfs-common` for Longhorn.
- Loads `iscsi_tcp` (now and at boot) and starts `iscsid`.
- Turns swap off, now and in `/etc/fstab`.
- Writes `/etc/rancher/rke2/config.yaml` with `ingress-controller: none`. Since v1.36, RKE2 deploys its own Traefik on ports 80/443. The homelab Traefik chart provides ingress on 8080/8443 instead.
- Installs RKE2 as a server and starts `rke2-server`, then waits until the API answers.
- Puts `kubectl` (from RKE2) on PATH, and copies the admin kubeconfig to `/home/debian/.kube/config`.
- Installs Helm and k9s.
- Applies the [basic hardening](../README.md#basic-hardening-work-in-progress).

The worker seed installs the Longhorn prerequisites and the RKE2 agent, and starts the agent only when it has join settings (see below). Use kubectl, Helm, and k9s on the control plane or the Mac.

## Pinned versions

| Tool | Pin | How it is checked |
|---|---|---|
| RKE2 | `v1.36.5+rke2r1` | Versioned `install.sh` checked against SHA-256 here; it verifies the release tarball. |
| Helm (control plane) | `v4.3.0` | SHA-256 per architecture |
| k9s (control plane) | `v0.51.0` | SHA-256 per architecture |

## Provision

From `infratructure/on-premises/virtual-machine/debian13/`:

```sh
./install.sh rke2 control-plane-node debian@10.10.10.101
```

Then check on the node: `cloud-init status --long`, `sudo systemctl status rke2-server`, and `kubectl get nodes` after logging in again.

## Join nodes to a cluster

Join the worker to the control plane:

```sh
./install.sh --join debian@10.10.10.101 rke2 worker-node debian@10.10.10.102 homelab-k8s-node-wk0
./install.sh --join debian@<cp0-ip> rke2 control-plane-node debian@<ip> homelab-k8s-node-cp1
./install.sh --join-only debian@<cp0-ip> rke2 worker-node debian@<ip>    # a worker provisioned earlier
```

Before the seed runs, `install.sh` reads the token on the control plane (the agent token for workers) and writes `server: https://<cp0-ip>:9345` and `token:` to `/etc/rancher/rke2/config.yaml.d/50-join.yaml` (mode 0600) on the new node. The token passes through files, never the seed or command arguments. The seed then starts `rke2-server` or `rke2-agent` already joined, and `install.sh` waits until the node is `Ready`.

- The token is long-lived: anyone with it can join nodes. Keep it out of Git; rotate it with `rke2 token rotate`.
- A control plane provisioned without `--join` has started its own cluster (its own etcd), so `--join-only` refuses it: provision it again with `--join`.
- Node names must be unique. A reinstalled machine with an old name is rejected until you run `kubectl delete node <name>`.
- etcd needs three servers (an odd number) for high availability. The joining nodes point at cp0's IP; for HA, use a fixed address (a VIP or DNS name, added to `tls-san`) once the LAN is defined.
- Ports between nodes: 9345 (registration) and 6443 (API) on the servers, plus the CNI's ports.

## Not done yet

- **Storage:** RKE2 has no default StorageClass. The [RKE2 Helm profile](../../../../../helm/deployment/dev/homelab-rke2-cluster-dev/README.md) deploys local-path-provisioner behind `homelab-pvc-storage`; the Longhorn chart adds replicated volumes across both nodes.
- **LAN networking and DNS:** ingress hostnames still need DNS records or client hosts entries; see the [RKE2 profile guide](../../../../../helm/deployment/dev/homelab-rke2-cluster-dev/README.md).
- **High availability:** this development cluster has one control plane and is not highly available; etcd quorum needs three server nodes.
