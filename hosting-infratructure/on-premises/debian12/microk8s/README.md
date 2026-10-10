# MicroK8s on Debian 12 in UTM

The first provisioning step creates a NoCloud seed ISO. Each VM needs its own ISO so cloud-init assigns a unique instance ID and hostname.

## Create a seed ISO

Run these commands from this directory on macOS:

```sh
./control-plane-node/generate-cloud-init-iso.sh
```

This creates `control-plane-node/cloud-init.iso`. You can override the hostname and output path:

```sh
./control-plane-node/generate-cloud-init-iso.sh cp0 ./cp0-seed.iso
./worker-node/generate-cloud-init-iso.sh wk0 ./wk0-seed.iso
```

The ISO contains NoCloud seed data; it is not a bootable Debian installer.

The cloud-init config updates Debian, installs MicroK8s plus Helm and kubectl, enables MicroK8s hostpath storage for the development PostgreSQL PVC, installs k9s from its official GitHub release with SHA-256 verification, adds the `debian` user to the `microk8s` group, and waits for MicroK8s to become ready. It keeps the Debian install's existing password available for SSH login. This password-based access is intended for the isolated local learning VM, not a production server.

## Provision a fresh Debian VM over SSH

Install Debian 12 in UTM with the `debian` user and OpenSSH server selected. Keep UTM Shared Network enabled so the VM can reach package mirrors. Then run the helper from this directory on macOS:

```sh
./provision-cloud-init-via-ssh.sh control-plane-node debian@192.168.64.3
```

The helper generates the seed ISO, copies it and a small runner to Debian, installs `cloud-init`, stages the NoCloud files, and runs cloud-init. It may prompt for SSH and sudo passwords. Change the target IP if UTM assigned a different address. When provisioning finishes, check `cloud-init status --long`, `microk8s status --wait-ready`, `kubectl get pods -A`, `helm version`, and `k9s version`.

## Attach the seed ISO manually (optional)

If cloud-init is already installed in Debian, you can attach the seed ISO to the VM as a CD/DVD drive and reboot. Cloud-init must discover the NoCloud seed during boot. To build a seed for another hostname:

```sh
./control-plane-node/generate-cloud-init-iso.sh cp0 ./cp0-seed.iso
```

## Provision an existing Debian VM over SSH without cloud-init

If the Debian installation does not have cloud-init, you can provision it directly over SSH instead. This route does not need either seed ISO. The VM must be reachable from the Mac over SSH, and the SSH user must have `sudo` access. The command uploads the guest-side script, runs it with `sudo`, and removes the temporary copy afterward. It may prompt for the SSH and sudo passwords.

From this directory, run:

```sh
./provision-via-ssh.sh control-plane-node debian@192.168.64.3
```

The default hostname is `cp0`; for the worker, use `worker-node` and it defaults to `wk0`. You can pass a different hostname as the third argument. After provisioning finishes, log out and back in so the `microk8s` group membership applies, then run the checks above.

The guest script is [provision-microk8s-node.sh](provision-microk8s-node.sh); it installs snapd, MicroK8s, Helm, and kubectl, installs k9s from its official GitHub release with SHA-256 verification, configures the hostname and kubeconfig, and waits for MicroK8s to become ready.

## Check provisioning

On `cp0`, log in as `debian` and run:

```sh
microk8s status --wait-ready
microk8s kubectl get nodes
kubectl get pods -A
helm version
k9s version
```

Cloud-init output is available in `/var/log/cloud-init-output.log`; overall status is available with `cloud-init status --long`.
