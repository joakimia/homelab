# UTM MicroK8s development profile

Deploys platform, cert-manager with the `homelab-ca` issuer, Traefik, PostgreSQL, PgBouncer, pgAdmin, the Caddy homepage, and Authelia to the MicroK8s VM in UTM. The order and Helm flags are in `deploy-set.json`, and the per-chart overrides are in `<chart>/values.yaml`. Every workload runs one replica.

## Quick start

Provision the VM first ([guide](../../../../infratructure/on-premises/debian12/README.md)), then run this from the repository root on the Mac:

```sh
VM_IP=192.168.64.9      # in the VM console: ip -4 -o addr show dev enp0s1
infratructure/on-premises/debian12/install.sh microk8s control-plane-node "debian@$VM_IP"
helm/deployment/dev/local-microk8s-cluster-dev/install.sh "debian@$VM_IP"
curl --cacert .local/homelab-ca/ca.crt --resolve "homepage.homelab.com:8443:$VM_IP" https://homepage.homelab.com:8443/
```

## Entry points

| Command (from the Mac) | What it does |
|---|---|
| `install.sh debian@<ip>` | Copies `helm/charts` and this profile to `~/homelab-deploy/local-microk8s-cluster-dev` on the VM over SSH, then runs `deploy.sh --local` there. Needs only `ssh`/`scp` on the Mac. |
| `deploy.sh debian@<ip>` | Copies the VM's kubeconfig to `./.local/local-microk8s-cluster-dev.kubeconfig`, with the context renamed to `local-microk8s-cluster-dev`, and runs Helm on the Mac against the VM. Needs `helm`, `kubectl`, and `jq` on the Mac. Your default kubeconfig is not touched. |
| `deploy.sh --kubeconfig debian@<ip>` | Only refreshes `./.local/local-microk8s-cluster-dev.kubeconfig`, for example for k9s. |
| `deploy.sh --local` | Deploys to the current kubectl context (used on the VM). |

Each chart's `scripts/install.sh` creates its Secrets only if they are missing. Helm waits up to 10 minutes per chart and rolls back on failure. Reruns are safe. The pgAdmin login is printed once, on first install.

k9s from the repository root:

```sh
helm/deployment/dev/local-microk8s-cluster-dev/deploy.sh --kubeconfig "debian@$VM_IP"
KUBECONFIG=.local/local-microk8s-cluster-dev.kubeconfig k9s
```

## Secrets and database access

| Namespace | Secret | Keys | Created by |
|---|---|---|---|
| `hlab-database` | `postgres-credentials` | `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` | `postgres` install script; also used by PgBouncer |
| `hlab-database` | `postgres-admin` | `PASSWORD` | `postgres` install script; password of the `homelab-admin` role |
| `hlab-frontend-apps` | `pgadmin-credentials` | `PGADMIN_DEFAULT_EMAIL`, `PGADMIN_DEFAULT_PASSWORD` | `pgadmin` install script |
| `hlab-platform` | `authelia` | `JWT_SECRET`, `SESSION_SECRET`, `STORAGE_ENCRYPTION_KEY`, `users_database.yml` | `authelia` install script; prints the admin login once |

In pgAdmin, register PostgreSQL directly: `postgres.hlab-database.svc.cluster.local:5432`, database `homelab`, user `homelab-admin` (password printed by the first postgres install, or in the `postgres-admin` Secret). Apps use PgBouncer (`pgbouncer.hlab-database.svc.cluster.local:6432`). Read the password with:

```sh
kubectl get secret postgres-credentials -n hlab-database -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d; echo
```

PostgreSQL uses the `homelab-pvc-storage` class. The platform chart creates it from this profile's overlay, with MicroK8s's `microk8s.io/hostpath` provisioner.

## HTTPS

The first `install.sh` creates a local CA in `./.local/homelab-ca/` and trusts it in the macOS keychain (asks for your password once). cert-manager signs a certificate for each Ingress host with it, so `https://homepage.homelab.com:8443/` opens without a warning. All clusters share the CA. See [cert-issuers](../../../charts/cert-issuers/README.md).

```sh
kubectl get certificate -A   # READY True; otherwise Traefik serves its self-signed default
```

## Login

The homepage and pgAdmin require an Authelia login (`https://auth.homelab.com:8443/`, user printed by the first install) and are HTTPS only. pgAdmin logs you in as the Authelia user.

## Reach it from the Mac

Traefik listens on host ports **8443** (HTTPS) and 8080 (HTTP); ports 443 and 80 are not used, so URLs include the port. An Ingress hostname does not create DNS. Either use `curl --resolve` as in the quick start, or add `/etc/hosts` entries for `homepage.homelab.com`, `pgadmin.homelab.com`, and `auth.homelab.com` pointing to the VM. 

UTM Shared Network uses DHCP on `192.168.64.0/24`, with gateway and DNS at `192.168.64.1`, so the VM address can change. Update `/etc/hosts` and rerun `deploy.sh --kubeconfig` when it does. For a fixed address, either:

- narrow UTM's DHCP range (for example `.100`–`.254`) and add a NoCloud `network-config` for `enp0s1`, for example `192.168.64.10/24`. The seed generator does not emit `network-config` yet; or
- use bridged networking with a DHCP reservation on the LAN router.

These `192.168.64.x` settings apply only to this UTM VM. RKE2 on hardware will get its own profile with LAN addressing, DNS, storage, and ingress choices.
