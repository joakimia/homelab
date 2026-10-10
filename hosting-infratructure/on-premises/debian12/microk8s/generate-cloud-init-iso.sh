#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  echo "Usage: $0 <control-plane-node|worker-node> [hostname] [output.iso]" >&2
}

if [[ $# -lt 1 || $# -gt 3 ]]; then
  usage
  exit 2
fi

role=$1

case "$role" in
  control-plane-node) default_hostname=cp0 ;;
  worker-node) default_hostname=wk0 ;;
  *) usage; echo "Unknown node role: $role" >&2; exit 2 ;;
esac

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
hostname=${2:-$default_hostname}
output=${3:-$script_dir/$role/cloud-init.iso}

if [[ ! "$hostname" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]]; then
  echo "Invalid hostname: $hostname" >&2
  exit 2
fi

source_file="$script_dir/$role/cloud-init.yaml"

if [[ ! -f "$source_file" ]]; then
  echo "Cloud-init config not found: $source_file" >&2
  exit 1
fi

command -v hdiutil >/dev/null || { echo "hdiutil is required (run this on macOS)." >&2; exit 1; }
output_dir=$(cd -- "$(dirname -- "$output")" && pwd)
output="$output_dir/$(basename -- "$output")"
build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT

cp "$source_file" "$build_dir/user-data"
cat > "$build_dir/meta-data" <<EOF
instance-id: homelab-$hostname
local-hostname: $hostname
EOF

hdiutil makehybrid -ov -o "$output" -iso -joliet -default-volume-name cidata "$build_dir" >/dev/null
echo "Created $output for $role ($hostname). Attach it as a CD/DVD drive to the UTM VM."
