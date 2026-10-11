#!/usr/bin/env bash
# Installs or upgrades the homepage release. Needs the platform release for its namespace.
# Extra arguments are passed to helm upgrade, for example --values <profile overlay>.
set -euo pipefail
export LC_ALL=C  # English messages from bash and tools, whatever the local language

chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
namespace=hlab-frontend-apps

for command in helm kubectl; do
  command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; exit 1; }
done

kubectl get namespace "$namespace" >/dev/null || { echo "Namespace $namespace is missing; install the platform chart first." >&2; exit 1; }

helm upgrade --install homepage "$chart_dir" --namespace "$namespace" "$@"
