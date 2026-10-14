---
name: debian-cloud-init
description: Provision or troubleshoot Debian 12 machines (Kubernetes nodes and the jumpbox; MicroK8s in UTM now, RKE2 on hardware later) using NoCloud cloud-init seeds and the shared install.sh over SSH.
---

# Debian 12 with NoCloud cloud-init

Use this skill when you provision a fresh Debian machine, change a cloud-init seed, or diagnose provisioning over SSH. The flow is the same on a UTM VM and on hardware. Only the network details differ (see the UTM section).

## Workflow

1. Read `AGENTS.md`, `infratructure/on-premises/virtual-machine/debian12/README.md`, and the README for the seed (`microk8s/`, `rke2/`, or `jumpbox/`) first.
2. Confirm the target address, the Debian user (`debian`, with sudo; the installer's root password left empty), and which seed is being provisioned. Never assume an earlier machine or package installation still exists.
3. A minimal Debian install may not include cloud-init. Use these commands:
   - `debian12/install.sh <microk8s|rke2> <role> debian@<ip>` or `install.sh jumpbox debian@<ip>` installs cloud-init over SSH, stages the seed, and runs it.
   - `install.sh --iso ...` only builds a seed ISO for a machine that already has cloud-init. A seed ISO is not a bootable Debian installer.
4. Keep the layout:
   - One shared `debian12/install.sh`, plus `<distro>/<role>/cloud-init.yaml` per node role and `jumpbox/cloud-init.yaml`.
   - Put new provisioning steps in the seeds, and new modes or host-side logic in `install.sh`. Do not add helper scripts or a second bootstrap path.
   - Pin tool versions in the seeds (snap tracks, or exact releases with SHA-256 per architecture) and update the README version tables.
   - Host-side code must work on macOS (bash 3.2) and Linux. Generated files, such as seed ISOs, go to the directory the script is run from.
5. The jumpbox is not a cluster node. It hosts the local registry and receives the provisioning bundle (`~/homelab-bundle`), so nodes can be provisioned from it with the jumpbox's own SSH key.
6. Ask the operator to type SSH and sudo passwords interactively. Never put passwords in arguments, scripts, logs, or Git. Only the first run needs the SSH password; the seed authorizes the provisioning machine's public key.
7. After provisioning, check `cloud-init status --long`, `/var/log/cloud-init-output.log`, and, as appropriate, `microk8s status --wait-ready` or `systemctl status rke2-server`, then `kubectl get nodes`, `helm version`, and `k9s version`. Report which checks ran and their results.
8. For seed changes, run `tests/check.sh seeds` (YAML parsing and `dash -n` on each `runcmd` block; cloud-init runs them with `/bin/sh`, which is dash on Debian). A new seed or check belongs in `check.sh` in the same change. Do not provision a machine unless the user asks.

## Known pitfalls

- **Lost IPv4 about an hour after provisioning** (`network is unreachable` on the node, the Mac cannot reach it, `enp0s1` has only IPv6): cloud-init rewrote the installer's network config on the running system and stopped `dhclient`, so the DHCP lease expired. `install.sh` now writes `/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg` before running the seed. On an affected node, run `sudo systemctl restart networking` from the console. To confirm, `pgrep dhclient` is empty and `/etc/network/interfaces.d/50-cloud-init` exists.

- **IP changed after a DHCP lease ran out:** the node's `~/.kube/config` from older seeds points at the old IP. It should point at `127.0.0.1`, as the current seeds do: `microk8s config | sed 's#server: https://.*:16443#server: https://127.0.0.1:16443#' > ~/.kube/config`. On the Mac, rerun `deploy.sh --kubeconfig debian@<new-ip>` and update `/etc/hosts`. If the API certificate lacks the new IP, run `sudo microk8s refresh-certs --cert server.crt`.
- **Rebuilt machine on the same IP:** SSH reports a changed host key. Verify the new fingerprint with the user or on the console, then run `ssh-keygen -R <ip>`. Do not disable host-key checking.
- **SSH control sockets:** the path must stay under about 104 bytes, so `install.sh` keeps them in `/tmp/homelab-ssh.*` rather than macOS's long `$TMPDIR`.
- **Group membership:** changes such as adding `debian` to `microk8s` need a new login session.
- **SSH host keys:** a reboot or `cloud-init clean` can regenerate them. A changed-key warning is not the same as a wrong password.

## UTM specifics (current MicroK8s VM)

- UTM Shared Network uses DHCP on `192.168.64.0/24`, with gateway and DNS at `192.168.64.1`. Find the guest IP in the console with `ip -4 -o addr show dev enp0s1`. The address can change.
- `install.sh --iso` output can be attached as a CD/DVD drive in UTM.
- These network details do not carry over to RKE2 on hardware; the home LAN needs its own addressing and DNS.
