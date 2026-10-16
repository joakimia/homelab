#!/usr/bin/env bash
# Installs or upgrades one shared PersistentVolumeClaim as its own release. The homelab chart normally
# includes this chart instead (see ../homelab).
#
#   ./install.sh <release> --values <claim values> [helm flags]
#
# The resources use the namespace in the values; the release record is kept in default.
set -euo pipefail
export LC_ALL=C  # English messages from bash and tools, whatever the local language

chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  echo "Usage: $0 <release> --values <claim values> [helm flags]" >&2
  exit 2
}

[[ $# -ge 1 && "$1" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]] || usage
release=$1
shift

for command in helm kubectl; do
  command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; exit 1; }
done

helm upgrade --install "$release" "$chart_dir" --namespace default "$@"
