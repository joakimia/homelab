# RKE2 on Debian 12

**Work in progress.** These seeds have only been checked for syntax; they have not run on a VM or on hardware yet. RKE2 on physical hardware is the later goal. Define the home LAN's addressing, DNS, and routing for it separately: the UTM `192.168.64.x` setup does not carry over.

## What the control-plane seed does

- Updates Debian and installs `curl` and `jq`.
- Turns swap off, now and in `/etc/fstab`.
- Writes `/etc/rancher/rke2/config.yaml` with `ingress-controller: none`. Since v1.36, RKE2 deploys its own Traefik on ports 80/443. The homelab Traefik chart provides ingress on 8080/8443 instead.
- Installs RKE2 as a server and starts `rke2-server`, then waits until the API answers.
- Puts `kubectl` (from RKE2) on PATH, and copies the admin kubeconfig to `/home/debian/.kube/config`.
- Installs Helm and k9s.
- Applies the [basic hardening](../README.md#basic-hardening-work-in-progress).

The worker seed installs the RKE2 agent, Helm, and k9s, but does not join or start yet. Joining needs the server URL (`https://<control-plane-ip>:9345`) and the token from `/var/lib/rancher/rke2/server/node-token` in `/etc/rancher/rke2/config.yaml`. Keep the token out of Git.

## Pinned versions

| Tool | Pin | How it is checked |
|---|---|---|
| RKE2 | `v1.36.5+rke2r1` | Versioned `install.sh` checked against SHA-256 here; it verifies the release tarball. |
| Helm | `v4.3.0` | SHA-256 per architecture |
| k9s | `v0.51.0` | SHA-256 per architecture |

## Provision

From `infratructure/on-premises/debian12/`:

```sh
./install.sh rke2 control-plane-node debian@<ip>
```

Then check on the node: `cloud-init status --long`, `sudo systemctl status rke2-server`, and `kubectl get nodes` after logging in again.

## Not done yet

- **Storage:** RKE2 has no default StorageClass. The UTM Helm profile's `homelab-pvc-storage` uses the MicroK8s hostpath provisioner, so an RKE2 Helm profile needs another provisioner, for example local-path or Longhorn.
- **Joining nodes:** the worker seed does not join the control plane yet.
- **LAN networking and DNS:** not defined yet.
- **Helm profile:** there is no RKE2 profile in `helm/deployment/` yet.
