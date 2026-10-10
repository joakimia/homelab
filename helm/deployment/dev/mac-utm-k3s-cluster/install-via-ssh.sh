#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! "$1" =~ ^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+$ ]]; then
  echo "Usage: $0 user@vm-ip" >&2
  exit 2
fi

target="$1"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../../.." && pwd)"
temp_archive="$(mktemp -t homelab-dev-charts.XXXXXX.tar.gz)"
remote_dir="homelab-dev-deploy"
trap 'rm -f "$temp_archive"' EXIT

command -v ssh >/dev/null || { echo "ssh is required" >&2; exit 1; }
command -v scp >/dev/null || { echo "scp is required" >&2; exit 1; }

tar -czf "$temp_archive" -C "$repo_root" \
  helm/charts/install-chart.sh \
  helm/charts/platform \
  helm/charts/traefik \
  helm/charts/homepage \
  helm/charts/postgres \
  helm/charts/pgbouncer \
  helm/charts/pgadmin \
  helm/deployment/dev/mac-utm-k3s-cluster

echo "Copying the development charts to $target (enter the SSH password if prompted)."
ssh "$target" "mkdir -p '$remote_dir'"
scp "$temp_archive" "$target:$remote_dir/charts.tar.gz"
ssh -t "$target" "export PATH=/snap/bin:/usr/local/bin:\$PATH; tar -xzf '$remote_dir/charts.tar.gz' -C '$remote_dir' && cd '$remote_dir/helm/deployment/dev/mac-utm-k3s-cluster' && bash ./install.sh"
