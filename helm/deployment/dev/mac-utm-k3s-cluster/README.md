# UTM MicroK8s development stack

This profile installs the charts that are currently in use: platform, Traefik, PostgreSQL, PgBouncer, pgAdmin, and a small Caddy homepage. Run `install.sh` on the Debian VM after provisioning, or from any machine whose `kubectl` context points at this MicroK8s cluster.

## Fresh Debian VM

The NoCloud ISO cannot install cloud-init before cloud-init itself exists. Install a minimal Debian 12 system with network access, then install the package and reboot once with the generated seed ISO attached:

```sh
sudo apt update
sudo apt install -y cloud-init
sudo reboot
```

Create the control-plane ISO from `hosting-infratructure/on-premises/debian12/microk8s/control-plane-node/generate-cloud-init-iso.sh`, attach it in UTM, and boot. Cloud-init installs MicroK8s, Helm, kubectl, k9s, and enables the `microk8s-hostpath` storage class. After provisioning, log out and back in so the `microk8s` group membership applies. Check `cloud-init status --long`, `microk8s status --wait-ready`, `kubectl get nodes`, `helm version`, and `kubectl get storageclass`.

For an existing Debian VM, the repository also has `hosting-infratructure/on-premises/debian12/microk8s/provision-via-ssh.sh`; it installs the same tools over SSH and prompts for credentials as needed.

## Install the charts

From this directory on the Debian VM (or with the correct cluster context):

```sh
./install.sh
```

From the Mac, the helper packages the selected charts, copies them to the VM, and runs the same installer there:

```sh
./install-via-ssh.sh debian@192.168.64.3
```

On the Mac, `k9s-connect.sh` copies a kubeconfig from the VM and replaces its loopback API address with the VM's address. It writes a separate kubeconfig at `.local/homelab-kubeconfig` so it does not replace your default contexts. The file is ignored by Git because it contains client credentials. Run these commands on the Mac:

```sh
./k9s-connect.sh debian@192.168.64.3
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

Traefik listens on ports 80 and 443 on the VM node. For a temporary HTTP test without changing Mac DNS:

```sh
curl --resolve homepage.homelab.com:80:192.168.64.3 http://homepage.homelab.com/
curl --resolve pgadmin.homelab.com:80:192.168.64.3 -I http://pgadmin.homelab.com/
```

The homepage also has a hostless fallback, so `http://192.168.64.3/` opens it directly in a browser. To use the named URLs, configure Mac DNS or add host mappings for `homepage.homelab.com` and `pgadmin.homelab.com` pointing at the VM IP. Ensure the VM keeps a stable/reserved address.

This is the development profile for the UTM MicroK8s cluster. RKE2-specific storage, ingress exposure, and secrets should be supplied by a later environment profile and Ansible automation; no production environment is configured here.
