# RKE2 development profile

Deploys the same stack as the [MicroK8s profile](../local-microk8s-cluster-dev/README.md) (platform, cert-manager with the `homelab-ca` issuer, Traefik, PostgreSQL, PgBouncer, pgAdmin, the `homelab` chart, and the observability stack) to a two-node RKE2 cluster on Proxmox, plus Longhorn. The control-plane node is `10.10.10.101`; the worker is `10.10.10.102`. The hosts are `*.joakimia.dev`, served through a Cloudflare Tunnel with Let's Encrypt certificates (see below). There is no Authelia here, so Grafana uses its own login; Cloudflare Access is the login in front of every host except the homepage. The order and Helm flags are in `deploy-set.json`. Every workload runs one replica; Longhorn volumes use two replicas across the two nodes.

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

The `homelab` SSH alias must connect to the Proxmox server over Tailscale. On that server, `~/.kube/config` uses the `homelab-server` context and reaches cp0 directly on the VM network. The apps are at `https://<app>.joakimia.dev/` (homepage, pgadmin, grafana, prometheus, longhorn) through Cloudflare; see the next section. To skip Cloudflare on the LAN, point a host to `10.10.10.101` in `/etc/hosts` and use port 8443.

The Mac's SSH tunnel exposes the Kubernetes API only. Direct browser access to the ingress through Tailscale also needs a subnet route to `10.10.10.101/32` advertised by the Proxmox server and approved in the Tailscale admin console; that route is not currently enabled. The Traefik dashboard is disabled in this profile because it has no authentication configured.

## Public access through Cloudflare

[`infratructure/cloudflare`](../../../../infratructure/cloudflare/README.md) creates the tunnel, the `*.joakimia.dev` DNS record, the Access login, and the cert-manager token with OpenTofu. Apply it before the first deploy. Then the profile installs:

- [`cloudflared`](../../../charts/cloudflared/README.md): two connectors in `hlab-networking` that send every `*.joakimia.dev` request to Traefik on 8443.
- `cert-issuers` with `acme.enabled`: the `letsencrypt` ClusterIssuer (DNS-01 through Cloudflare), used by every Ingress in this profile.

On the first install, the chart scripts ask for both tokens. Over SSH they run on the node, so paste them from `tofu output -raw tunnel_token` and `tofu output -raw cert_manager_api_token`. Check the result:

```sh
kubectl -n hlab-networking get pods -l app.kubernetes.io/name=cloudflared   # Ready = connected to Cloudflare
kubectl get certificate -A                                                  # READY True from letsencrypt
curl -sI https://homepage.joakimia.dev/                                     # 200, no login
curl -sI https://grafana.joakimia.dev/                                      # 302 to the Access login
```

## authentik

The [`authentik`](../../../charts/authentik/README.md) identity provider runs in `hlab-platform` at `https://authentik.joakimia.dev/`. Its database and role come from `postgres/values.yaml` (`roles.authentik`, `databases.authentik`); the postgres installer generates the role's password and the authentik installer copies it, so deploy `postgres` before `authentik`. The first install prints the `akadmin` password once. Then log in, and in the embedded outpost set `authentik_host` to `https://authentik.joakimia.dev/` before you use proxy providers.

```sh
kubectl -n hlab-platform get pods -l app.kubernetes.io/name=authentik   # server and worker Ready
curl -sI https://authentik.joakimia.dev/-/health/ready/                     # 200 (behind Access: 302)
```

If you created `homelab-pvc-storage` by hand while testing, delete it first (`kubectl delete storageclass homelab-pvc-storage`). Otherwise the platform release cannot adopt it, and a StorageClass's provisioner cannot be changed in place.

## Check the storage

```sh
export KUBECONFIG=.local/homelab-rke2-cluster-dev.kubeconfig
kubectl get storageclass homelab-pvc-storage     # PROVISIONER rancher.io/local-path
kubectl -n hlab-storage get pods                 # local-path-provisioner Running
kubectl -n hlab-database get pvc                 # postgres PVC Bound
```

A PVC that stays `Pending` shows the reason in `kubectl -n hlab-database describe pvc`, not on the pod. The provisioner logs (`kubectl -n hlab-storage logs deploy/local-path-provisioner`) show failed helper pods.
