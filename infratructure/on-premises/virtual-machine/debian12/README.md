# Debian 12 nodes with cloud-init

One script provisions Debian 12 VMs or machines: Kubernetes nodes and the jumpbox in front of them. Each folder holds a NoCloud seed (`cloud-init.yaml`).

```text
install.sh                                                   # the only script; macOS or Linux
microk8s/{control-plane-node,worker-node}/cloud-init.yaml    # current UTM learning cluster
rke2/{control-plane-node,worker-node}/cloud-init.yaml        # work in progress, later on hardware
jumpbox/cloud-init.yaml                                      # work in progress: tools, registry
```

## Before you start

Install Debian 12 with a `debian` user that can use `sudo` (leave the root password empty in the installer), the OpenSSH server, and network access. If the new machine reuses an old IP, remove the stale host key on the Mac first: `ssh-keygen -R <ip>`.

## Usage

```sh
./install.sh microk8s control-plane-node debian@<ip> [hostname]    # default homelab-cp0
./install.sh rke2 control-plane-node debian@<ip> [hostname]        # default homelab-rke2-cp0
./install.sh jumpbox debian@<ip> [hostname]                        # default homelab-jumpbox
./install.sh --iso <microk8s|rke2> <role> [hostname] [output.iso]  # seed ISO only
./install.sh --iso jumpbox [hostname] [output.iso]
```

Over SSH (the default), `install.sh`:

1. renders `user-data` from the seed and adds this machine's SSH public key, and writes `meta-data` with the hostname;
2. copies both to the machine;
3. installs `cloud-init` there if it is missing, stops it from managing networking (the installer's DHCP setup stays), stages the seed, and runs it;
4. for the jumpbox only, copies the bundle (this folder and `helm/`) to `~/homelab-bundle`.

You type the SSH password once and the sudo password once. After that, SSH works with the key. The key is the first of `~/.ssh/id_ed25519.pub`, `id_ecdsa.pub`, and `id_rsa.pub`; choose another with `HOMELAB_SSH_PUBLIC_KEY=/path/to/key.pub`.

`--iso` writes `<hostname>-seed.iso` to the directory you run it from. Attach it as a CD/DVD drive to a VM that already has cloud-init. It uses `hdiutil` on macOS or `xorriso`/`genisoimage` on Linux.

## Basic hardening (work in progress)

The last steps of every seed apply a small baseline and print the result to `/var/log/cloud-init-output.log`:

- SSH: `PermitRootLogin no`, `MaxAuthTries 3`, `X11Forwarding no` in `/etc/ssh/sshd_config.d/10-homelab-hardening.conf`. Password logins are turned off only if `install.sh` authorized a key; without a key they stay on so SSH still works. The UTM console accepts the password either way.
- Updates: `unattended-upgrades` installs Debian security updates daily and never reboots on its own.

Not included yet: a host firewall (MicroK8s and RKE2 manage iptables for pod networking, so it needs a planned port list), fail2ban, and CIS profiles. Check on the machine with `sudo sshd -T | grep -E 'passwordauth|permitroot'` and `sudo unattended-upgrade --dry-run --debug`.

What each seed installs, its pinned versions, and the checks to run afterwards are in [microk8s/](microk8s/README.md), [rke2/](rke2/README.md), and [jumpbox/](jumpbox/README.md).
