# Jumpbox

**Work in progress.** The seed has been checked for syntax and its registry config tested in a Debian 12 container. It has not run on a VM yet.

The jumpbox is the entry point to the cluster network. You reach it first, and from there you provision and deploy to the control-plane and worker nodes. It is **not** a Kubernetes node. It also hosts a local container registry.

## What the seed does

- Installs `curl`, `jq`, `git`, `openssh-client`, `xorriso` (for `install.sh --iso`), and `skopeo` (to copy images into the registry without Docker).
- Installs kubectl `v1.36.5`, Helm `v4.3.0`, and k9s `v0.51.0`, each checked against SHA-256 per architecture.
- Creates its own SSH key, `~/.ssh/id_ed25519`. Nodes provisioned from the jumpbox authorize this key automatically.
- Applies the [basic hardening](../README.md#basic-hardening-work-in-progress).
- Runs a local registry: Debian's `docker-registry` package (CNCF distribution 2.8), HTTP only on port **5000**, with images in `/var/lib/docker-registry`.

## Provision it

From `infratructure/on-premises/debian12/` on the Mac:

```sh
./install.sh jumpbox debian@<jumpbox-ip>          # hostname homelab-jumpbox
```

After cloud-init has run, `install.sh` copies the **bundle** to `~/homelab-bundle` on the jumpbox. The bundle is this provisioning folder plus `helm/`, without ISOs or `.local/`, and each run replaces it. Do not keep your own work in that folder.

## Use it

```sh
ssh debian@<jumpbox-ip>
cd ~/homelab-bundle/infratructure/on-premises/debian12
./install.sh rke2 control-plane-node debian@<node-ip>                       # provision a node
~/homelab-bundle/helm/deployment/dev/local-microk8s-cluster-dev/deploy.sh debian@<node-ip>   # deploy charts
```

The first `install.sh` run against a fresh node asks for the node's SSH and sudo passwords. From then on, the node accepts the jumpbox key. To reach such a node from the Mac, go through the jumpbox: `ssh -J debian@<jumpbox-ip> debian@<node-ip>`.

Copy an image into the registry:

```sh
skopeo copy --dest-tls-verify=false docker://docker.io/library/traefik:v3.7.14 docker://localhost:5000/traefik:v3.7.14
curl http://localhost:5000/v2/_catalog
```

## Not done yet

- **Registry clients:** the cluster nodes do not pull from the registry yet. Containerd on each node needs a mirror entry for `<jumpbox>:5000` over HTTP (RKE2: `/etc/rancher/rke2/registries.yaml`; MicroK8s: `certs.d/<host:port>/hosts.toml`). Pick a stable jumpbox address or DNS name first.
- **Registry security:** the registry has no TLS and no authentication. Keep it on the isolated lab network.
- **Network:** LAN addressing, DNS, and any firewall rules for the jumpbox are not defined yet.
- **Mac access to nodes:** nodes provisioned from the jumpbox only authorize the jumpbox key. Authorizing more than one key is not supported yet.
