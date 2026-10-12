#!/usr/bin/env bash
# Installs this profile on the VM over SSH: bundles helm/charts and this profile, copies the
# bundle to ~/homelab-deploy/<cluster> on the VM, and runs ./deploy.sh --local there with the
# VM's own kubeconfig. The profile folder name is the cluster name.
#
#   ./install.sh debian@<vm-ip>
#
# Only the SSH mode exists for now; a mode that runs directly on the VM can be added later.
set -euo pipefail
export LC_ALL=C  # English messages from bash and tools, whatever the local language

if [[ $# -ne 1 || ! "$1" =~ ^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+$ ]]; then
  echo "Usage: $0 debian@<vm-ip>" >&2
  exit 2
fi

target="$1"
profile_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$profile_dir/../../../.." && pwd)"
profile_path="${profile_dir#"$repo_root"/}"
cluster_name="$(basename "$profile_dir")"
remote_dir="homelab-deploy/$cluster_name"

command -v ssh >/dev/null || { echo "ssh is required" >&2; exit 1; }
command -v scp >/dev/null || { echo "scp is required" >&2; exit 1; }

temp_archive="$(mktemp "${TMPDIR:-/tmp}/homelab-$cluster_name.XXXXXX")"
# Short path: SSH control sockets are limited to about 104 bytes, and macOS $TMPDIR is long.
control_dir="$(mktemp -d /tmp/homelab-ssh.XXXXXX)"
# Share one SSH connection so a password (if no key is set up) is asked only once.
ssh_opts=(-o ControlMaster=auto -o "ControlPath=$control_dir/%C" -o ControlPersist=120)
trap 'ssh "${ssh_opts[@]}" -O exit "$target" 2>/dev/null || true; rm -rf "$temp_archive" "$control_dir"' EXIT

# macOS bsdtar stores Finder/provenance metadata that GNU tar on Debian warns about.
tar_opts=()
if tar --version 2>/dev/null | grep -q bsdtar; then
  tar_opts=(--no-mac-metadata --no-xattrs)
fi
COPYFILE_DISABLE=1 tar ${tar_opts[@]+"${tar_opts[@]}"} -czf "$temp_archive" -C "$repo_root" \
  helm/charts \
  "$profile_path"

echo "Copying the charts and $profile_path to $target..."
# Replace the previous bundle so removed files do not linger on the VM.
ssh "${ssh_opts[@]}" "$target" "rm -rf '$remote_dir' && mkdir -p '$remote_dir'"
scp "${ssh_opts[@]}" -q "$temp_archive" "$target:$remote_dir/charts.tar.gz"
ssh "${ssh_opts[@]}" -t "$target" "export PATH=/snap/bin:/usr/local/bin:\$PATH; tar -xzf '$remote_dir/charts.tar.gz' -C '$remote_dir' && cd '$remote_dir/$profile_path' && bash ./deploy.sh --local"
