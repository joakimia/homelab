#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! "$1" =~ ^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+$ ]]; then
  echo "Usage: $0 user@vm-ip" >&2
  exit 2
fi

target="$1"
host="${target##*@}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../../.." && pwd)"
config_dir="$repo_root/.local"
config_file="$config_dir/homelab-kubeconfig"
temp_file="$config_file.tmp"

mkdir -p "$config_dir"
chmod 700 "$config_dir"
trap 'rm -f "$temp_file"' EXIT
scp "$target:~/.kube/config" "$temp_file"
if ! HOMELAB_KUBECONFIG_HOST="$host" perl -0pi -e '
  $count = s{^(\s*server:\s*https://)[^/:\s]+(:\d+)?}{$1 . $ENV{HOMELAB_KUBECONFIG_HOST} . ($2 // "")}mge;
  END { exit($count ? 0 : 1) }
' "$temp_file"; then
  echo "Could not find an HTTPS Kubernetes API server in the VM kubeconfig" >&2
  exit 1
fi
chmod 600 "$temp_file"
mv "$temp_file" "$config_file"
echo "Wrote a private kubeconfig for $target to $config_file (ignored by Git)."
