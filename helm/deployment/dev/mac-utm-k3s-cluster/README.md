# UTM MicroK8s development stack

This profile installs the charts that are currently in use: platform, Traefik, PostgreSQL, PgBouncer, pgAdmin, and a small Caddy homepage. Run `install.sh` on the Debian VM after provisioning, or from any machine whose `kubectl` context points at this MicroK8s cluster.

## Fresh Debian VM

The NoCloud ISO cannot install cloud-init before cloud-init itself exists. Install a minimal Debian 12 system with network access, then install the package and reboot once with the generated seed ISO attached:

```sh
sudo apt update
sudo apt install -y cloud-init
sudo reboot
```

Create the control-plane ISO from `infratructure/on-premises/debian12/microk8s/control-plane-node/generate-cloud-init-iso.sh`, attach it in UTM, and boot. Cloud-init installs MicroK8s, Helm, kubectl, k9s, and enables the `microk8s-hostpath` storage class. After provisioning, log out and back in so the `microk8s` group membership applies. Check `cloud-init status --long`, `microk8s status --wait-ready`, `kubectl get nodes`, `helm version`, and `kubectl get storageclass`.

For an existing Debian VM, the repository also has `infratructure/on-premises/debian12/microk8s/provision-via-ssh.sh`; it installs the same tools over SSH and prompts for credentials as needed.

## Install the charts

From this directory on the Debian VM (or with the correct cluster context):

```sh
./install.sh
```

From the Mac, the helper packages the selected charts, copies them to the VM, and runs the same installer there. Find the guest IP with `ip -4 -o addr show dev enp0s1` in its console, then set `VM_IP` to that address:

```sh
VM_IP=192.168.64.6
./install-via-ssh.sh "debian@$VM_IP"
```

On the Mac, `k9s-connect.sh` copies a kubeconfig from the VM and replaces its loopback API address with the VM's address. It writes a separate kubeconfig at `.local/homelab-kubeconfig` so it does not replace your default contexts. The file is ignored by Git because it contains client credentials. Run these commands on the Mac:

```sh
VM_IP=192.168.64.6
./k9s-connect.sh "debian@$VM_IP"
./k9s.sh
```

The script upgrades/installs releases in dependency order, creates the credential Secrets only if missing, waits for workloads, and prints Ingresses. It is safe to rerun after chart changes. The database credentials stay in Kubernetes Secrets and outside Helm values. The script generates credentials on first install; it prints the initial pgAdmin login once.

The selected chart values set `replicaCount: 1` for Traefik, homepage, pgAdmin, PgBouncer, and PostgreSQL. Traefik is a Deployment; each replica needs a separate node because it binds host ports 80/443. PostgreSQL is constrained to one replica until replication is configured.

Retrieve the database password when needed with:

```sh
kubectl get secret postgres-credentials -n hlab-database \
  -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d; echo
```

Register the database in pgAdmin through PgBouncer at `pgbouncer.hlab-database.svc.cluster.local:6432`, using user `homelab`, database `homelab`, and the password retrieved above. The chart expects these Secrets and keys:

| Namespace | Secret | Required keys | Used by |
|---|---|---|---|
| `hlab-database` | `postgres-credentials` | `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` | PostgreSQL and PgBouncer |
| `hlab-frontend-apps` | `pgadmin-credentials` | `PGADMIN_DEFAULT_EMAIL`, `PGADMIN_DEFAULT_PASSWORD` | pgAdmin |

PostgreSQL defaults to the `homelab-pvc-storage` class. The platform release creates this class for the UTM profile using MicroK8s's `microk8s.io/hostpath` provisioner. The platform chart keeps future namespaces disabled. `hlab-networking` uses the `privileged` Pod Security profile because Traefik binds host ports 80/443; keep that namespace limited to trusted networking workloads.

## Reach it from the Mac

UTM Shared Network uses DHCP. This VM received `192.168.64.6` after its latest restart; `192.168.64.3` was an old address. Check the guest's current address with `ip -4 -o addr show dev enp0s1`, set it as `VM_IP` on the Mac, and refresh the private kubeconfig with `./k9s-connect.sh "debian@$VM_IP"` whenever it changes. The current subnet is `192.168.64.0/24`, with gateway and DNS at `192.168.64.1`. A candidate static guest address is `192.168.64.10`, but use it only after setting UTM's DHCP range to `192.168.64.100`–`192.168.64.254` and confirming no other VM uses `.10`. UTM exposes the guest subnet, host address, and DHCP bounds in its [network device settings](https://docs.getutm.app/settings-qemu/devices/network/network/).

Traefik listens on ports 80 and 443 on the VM node. For a temporary HTTP test without changing Mac DNS:

```sh
VM_IP=192.168.64.6 # replace with the guest's current DHCP address
curl --resolve "homepage.homelab.com:80:$VM_IP" http://homepage.homelab.com/
curl --resolve "pgadmin.homelab.com:80:$VM_IP" -I http://pgadmin.homelab.com/
```

The homepage also has a hostless fallback, so `http://$VM_IP/` opens it directly in a browser. If Mac `/etc/hosts` entries are used, update them whenever the DHCP address changes; this only configures that Mac. To use the `.10` static address in this UTM profile, narrow the UTM DHCP range as described above and add a NoCloud `network-config` file for `enp0s1` with `192.168.64.10/24`, default gateway `192.168.64.1`, and DNS `192.168.64.1`. Cloud-init reads networking from that separate file, not from `user-data`; the current seed generator does not yet emit it. For a stable address usable by other devices, use UTM bridged networking and create a DHCP reservation for the Debian guest's MAC address on the LAN router; add local DNS records there if the router supports them. Cloud-init can keep the guest on DHCP in that setup. RKE2 on physical hardware will need its own LAN-specific network, address, and DNS configuration; this UTM `192.168.64.x` setup does not carry over.

This is the development profile for the UTM MicroK8s cluster. Its shared-network DHCP address and local ingress instructions apply only to this VM. RKE2 on physical hardware will need a separate profile with addressing, DNS, storage, and ingress choices for the home LAN. RKE2-specific settings and secrets should be supplied by that environment profile and later Ansible automation; no production environment is configured here.
