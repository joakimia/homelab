# RKE2 development profile

Deploys the same stack as the [MicroK8s profile](../local-microk8s-cluster-dev/README.md) (platform, cert-manager with the `homelab-ca` issuer, Traefik, PostgreSQL, PgBouncer, pgAdmin, the `homelab` chart, and the observability stack) to a two-node RKE2 cluster on Proxmox, plus Longhorn. The control-plane node is `10.10.10.101`; the worker is `10.10.10.102`. There is no Authelia here, so Grafana uses its own login, and Prometheus (`prometheus.homelab.com`) and the Longhorn UI (`longhorn.homelab.com`) are open to everyone who reaches the node. The order and Helm flags are in `deploy-set.json`. Every workload runs one replica; Longhorn volumes use two replicas across the two nodes.

## What differs from MicroK8s

| Topic | MicroK8s | RKE2 |
|---|---|---|
| Storage | `microk8s.io/hostpath` addon | [`local-path-provisioner`](../../../charts/local-path-provisioner/README.md) chart in `hlab-storage`, volumes under `/opt/local-path-provisioner` on the node |
| `homelab-pvc-storage` provisioner | `microk8s.io/hostpath` | `rancher.io/local-path` |
| Replicated storage | none | [`longhorn`](../../../charts/longhorn/README.md) chart in `hlab-storage`, opt-in `longhorn` StorageClass with two replicas, used by the shared `homelab-shared` claim in `hlab-filestore`; the seed installs `open-iscsi` and `nfs-common` |
| Ingress | Homelab Traefik on 8080/8443 | Same; the seed turns off RKE2's bundled ingress controller |
| Node tools | `/snap/bin` | `/usr/local/bin` and `/var/lib/rancher/rke2/bin` |

Application charts only ask for `homelab-pvc-storage`, so they are the same in both profiles.

## Deploy and access

Provision the node with the [RKE2 seed](../../../../infratructure/on-premises/virtual-machine/debian13/rke2/README.md), then run this from the repository root on the Mac:

```sh
helm/deployment/dev/homelab-rke2-cluster-dev/install.sh debian@10.10.10.101
helm/deployment/dev/homelab-rke2-cluster-dev/deploy.sh --kubeconfig debian@10.10.10.101
```

The profile's `install.sh` bundles the charts and deploys them over SSH. The separate kubeconfig is written to `./.local/homelab-rke2-cluster-dev.kubeconfig`; it does not replace the Mac's default kubeconfig. It contains a direct `homelab-server` context and a `mac-via-ssh` context. On the Mac, keep this tunnel open in a terminal while using the latter:

```sh
ssh -N -L 16443:10.10.10.101:6443 homelab
KUBECONFIG=.local/homelab-rke2-cluster-dev.kubeconfig kubectl --context mac-via-ssh get nodes
```

The `homelab` SSH alias must connect to the Proxmox server over Tailscale. On that server, `~/.kube/config` uses the `homelab-server` context and reaches cp0 directly on the VM network. For HTTPS ingress, trust `.local/homelab-ca/ca.crt` on the Mac and point `homepage.homelab.com`, `pgadmin.homelab.com`, `grafana.homelab.com`, `prometheus.homelab.com`, and `longhorn.homelab.com` to `10.10.10.101` in DNS or `/etc/hosts`; the ingress entrypoint is port 8443.

The Mac's SSH tunnel exposes the Kubernetes API only. Direct browser access to the ingress through Tailscale also needs a subnet route to `10.10.10.101/32` advertised by the Proxmox server and approved in the Tailscale admin console; that route is not currently enabled. The Traefik dashboard is disabled in this profile because it has no authentication configured.

If you created `homelab-pvc-storage` by hand while testing, delete it first (`kubectl delete storageclass homelab-pvc-storage`). Otherwise the platform release cannot adopt it, and a StorageClass's provisioner cannot be changed in place.

## Check the storage

```sh
export KUBECONFIG=.local/homelab-rke2-cluster-dev.kubeconfig
kubectl get storageclass homelab-pvc-storage     # PROVISIONER rancher.io/local-path
kubectl -n hlab-storage get pods                 # local-path-provisioner Running
kubectl -n hlab-database get pvc                 # postgres PVC Bound
```

A PVC that stays `Pending` shows the reason in `kubectl -n hlab-database describe pvc`, not on the pod. The provisioner logs (`kubectl -n hlab-storage logs deploy/local-path-provisioner`) show failed helper pods.
