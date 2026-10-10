---
name: debian-utm-cloud-init
description: Provision or troubleshoot a clean Debian 12 UTM VM using NoCloud cloud-init, SSH, and the MicroK8s bootstrap scripts in this repository.
---

# Debian 12 in UTM with NoCloud

Use this skill when starting from a fresh Debian VM, changing the cloud-init seed, or diagnosing provisioning over SSH.

## Workflow

1. Read `AGENTS.md` and `infratructure/on-premises/debian12/microk8s/README.md` first. Treat the documented Mac-to-VM flow as canonical.
2. Confirm the guest address, Debian username, UTM shared-network access, and which profile is being provisioned. Never assume a prior VM or package installation still exists.
3. Remember that a minimal Debian install may not include cloud-init. The SSH helper installs/stages it and the NoCloud seed; a seed ISO is not a bootable Debian installer.
4. Use the repository scripts rather than copying a second, hand-maintained bootstrap. Ask the operator to enter SSH/sudo credentials interactively; never put passwords in command arguments, scripts, logs, or Git.
5. After provisioning, check `cloud-init status --long`, `/var/log/cloud-init-output.log`, `microk8s status --wait-ready`, `kubectl get nodes`, `helm version`, and `k9s version` as appropriate. Report which checks ran and their actual results.
6. If the user rebuilt the VM, expect SSH host keys to change. Verify the new key/fingerprint with the user or through a trusted local UTM console before replacing a known-host entry; do not disable host-key checking.

## Learning notes

- Cloud-init is the guest configuration mechanism, not a replacement for installing Debian.
- A reboot or `cloud-init clean` can regenerate SSH host keys. A changed-key warning is separate from a bad password.
- Group membership changes such as adding `debian` to `microk8s` generally require a new login session.
- Keep the current UTM workflow distinct from the future RKE2-on-hardware target.
