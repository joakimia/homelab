# RKE2 development profile

**Work in progress.** The charts pass `tests/check.sh` (lint and template), but this profile has not been deployed to an RKE2 node yet.

Deploys the same stack as the [MicroK8s profile](../local-microk8s-cluster-dev/README.md) (platform, Traefik, PostgreSQL, PgBouncer, pgAdmin, and the Caddy homepage) to a single RKE2 control-plane node, for now a VM in UTM. The order and Helm flags are in `deploy-set.json`. Only `platform/values.yaml` differs from the chart defaults. Every workload runs one replica.

## What differs from MicroK8s

| Topic | MicroK8s | RKE2 |
|---|---|---|
| Storage | `microk8s.io/hostpath` addon | [`local-path-provisioner`](../../../charts/local-path-provisioner/README.md) chart in `hlab-storage`, volumes under `/opt/local-path-provisioner` on the node |
| `homelab-pvc-storage` provisioner | `microk8s.io/hostpath` | `rancher.io/local-path` |
| Ingress | Homelab Traefik on 8080/8443 | Same; the seed turns off RKE2's bundled ingress controller |
| Node tools | `/snap/bin` | `/usr/local/bin` and `/var/lib/rancher/rke2/bin` |

Application charts only ask for `homelab-pvc-storage`, so they are the same in both profiles.

## Quick start

Provision the node with the [RKE2 seed](../../../../infratructure/on-premises/debian12/rke2/README.md), then run this from the repository root on the Mac:

```sh
NODE_IP=192.168.64.20   # in the VM console: ip -4 -o addr show dev enp0s1
infratructure/on-premises/debian12/install.sh rke2 control-plane-node "debian@$NODE_IP"
helm/deployment/dev/homelab-rke2-cluster-dev/install.sh "debian@$NODE_IP"
curl --resolve "homepage.homelab.com:8080:$NODE_IP" http://homepage.homelab.com:8080/
```

`install.sh` and `deploy.sh` work the same as in the MicroK8s profile; see its [entry points](../local-microk8s-cluster-dev/README.md#entry-points). The kubeconfig is written to `./.local/homelab-rke2-cluster-dev.kubeconfig` with context `homelab-rke2-cluster-dev`.

If you created `homelab-pvc-storage` by hand while testing, delete it first (`kubectl delete storageclass homelab-pvc-storage`). Otherwise the platform release cannot adopt it, and a StorageClass's provisioner cannot be changed in place.

## Check the storage

```sh
export KUBECONFIG=.local/homelab-rke2-cluster-dev.kubeconfig
kubectl get storageclass homelab-pvc-storage     # PROVISIONER rancher.io/local-path
kubectl -n hlab-storage get pods                 # local-path-provisioner Running
kubectl -n hlab-database get pvc                 # postgres PVC Bound
```

A PVC that stays `Pending` shows the reason in `kubectl -n hlab-database describe pvc`, not on the pod. The provisioner logs (`kubectl -n hlab-storage logs deploy/local-path-provisioner`) show failed helper pods.
