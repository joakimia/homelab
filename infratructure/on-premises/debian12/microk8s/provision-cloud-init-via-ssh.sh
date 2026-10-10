#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  echo "Usage: $0 <control-plane-node|worker-node> <user@host> [hostname]" >&2
}

if [[ $# -lt 2 || $# -gt 3 ]]; then
  usage
  exit 2
fi

role=$1
target=$2

case "$role" in
  control-plane-node)
    default_hostname=cp0
    ;;
  worker-node)
    default_hostname=wk0
    ;;
  *)
    usage
    echo "Unknown node role: $role" >&2
    exit 2
    ;;
esac

hostname=${3:-$default_hostname}

if [[ ! "$hostname" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]]; then
  echo "Invalid hostname: $hostname" >&2
  exit 2
fi

if [[ "$target" == -* || "$target" != *@* ]]; then
  echo "Use an SSH target in user@host form (for example debian@192.168.64.12)." >&2
  exit 2
fi

command -v ssh >/dev/null || { echo "ssh is required on this Mac." >&2; exit 1; }
command -v scp >/dev/null || { echo "scp is required on this Mac." >&2; exit 1; }

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
seed_iso="$script_dir/$role/cloud-init.iso"
apply_script="$script_dir/apply-cloud-init-seed.sh"
"$script_dir/generate-cloud-init-iso.sh" "$role" "$hostname"

remote_base=".homelab-cloud-init-$hostname-$$"
remote_script="$remote_base.sh"
remote_iso="$remote_base.iso"

echo "Copying the cloud-init seed ISO and runner to $target..."
scp "$seed_iso" "$target:$remote_iso"
scp "$apply_script" "$target:$remote_script"
echo "Installing cloud-init and running the NoCloud seed on $target. Enter the SSH and sudo passwords if prompted."
ssh -t "$target" "sudo bash '$remote_script' '$remote_iso' '$hostname'; result=\$?; rm -f '$remote_script' '$remote_iso'; exit \$result"
