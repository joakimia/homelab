# Ansible for the Proxmox host

**Work in progress.** Tested against `debian:13` containers (amd64 and arm64), not yet run against the Proxmox host.

The playbook prepares the Proxmox host (`homelab-server-0`) to deploy the [RKE2 profile](../../helm/deployment/dev/homelab-rke2-cluster-dev/README.md) with `deploy.sh --local`. Later it will also bootstrap secrets and similar host-side setup.

It manages:

- Packages `ca-certificates`, `curl`, `git`, `jq`, and `rsync`.
- Helm, kubectl, and OpenTofu in `/usr/local/bin`, each checked against SHA-256 per architecture (amd64, arm64). A binary is only replaced when its version differs from the pin, also when it is newer.
- A check (no changes) that the login user's `~/.kube/config` exists and has `homelab-server` as its current context, because `deploy.sh --local` uses the current context.

It does not manage the RKE2 VMs (cloud-init seeds in [`on-premises/virtual-machine/debian13`](../../infratructure/on-premises/virtual-machine/debian13/README.md) do), Proxmox itself, or the kubeconfig's contents.

## Layout

| Path | Purpose |
|---|---|
| `ansible.cfg` | Settings, read when you run from this folder |
| `inventory.yml` | Group `proxmox_hosts` with `homelab-server-0` |
| `proxmox-host.yml` | The playbook |
| `roles/tools/` | Packages and pinned binaries; versions in `vars/main.yml` |
| `roles/kubeconfig/` | The kubeconfig check |

The inventory connects through the `homelab` SSH alias, so the Tailscale address and user stay in `~/.ssh/config`, the same as for `ssh homelab`. Ansible runs as that user and uses sudo (`become`) only for packages and binaries. The host needs `python3` and the login user needs sudo.

## Versions

| Tool | Pin | How it is checked |
|---|---|---|
| Helm | `v4.3.0` | SHA-256 per architecture, same as the seeds |
| kubectl | `v1.36.5` | SHA-256 per architecture, same as the jumpbox seed |
| OpenTofu | `1.13.9` | SHA-256 per architecture from the release's `SHA256SUMS` |
| ansible-core, ansible-lint (Mac) | `2.22.0`, `26.11.0` | `mise.toml` |

## Install Ansible on the Mac

Both are pinned in the repository's `mise.toml`; run `mise install`. mise installs them with uv (pipx if uv is missing). ansible-core 2.22 needs Python 3.13 or newer, which uv downloads if needed, and ansible-lint uses its own copy of the same ansible-core version.

## Run

From this folder, preview first and then apply. `-K` (`--ask-become-pass`) prompts for the sudo password; it is never stored:

```sh
cd devops/ansible
ansible-playbook proxmox-host.yml --check --diff --ask-become-pass
ansible-playbook proxmox-host.yml --diff --ask-become-pass
```

A second run should report `changed=0`. Things to watch out for:

- `--check` needs `python3-apt` on the host; a normal run installs it.
- `--check` cannot download, so it only reports which binaries it would install.
- The package task runs `apt-get update` at most once a day. If the Proxmox enterprise repository is enabled without a subscription, that update fails; use the no-subscription repository instead.

Test it without the real host: `tests/check.sh ansible` lints it, and `tests/check.sh devops` runs it twice against a clean `debian:13` container over SSH (fixtures in [`tests/devops/ansible`](../../tests/devops/ansible/)); the second run must report `changed=0`. CI runs both.
