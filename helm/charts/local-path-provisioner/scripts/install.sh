#!/usr/bin/env bash
# Installs or upgrades the local-path-provisioner release. Needs the platform release for its
# namespace (hlab-storage, enabled in the profile overlay); platform also owns the StorageClass.
# Extra arguments are passed to helm upgrade, for example --values <profile overlay>.
set -euo pipefail
export LC_ALL=C  # English messages from bash and tools, whatever the local language

chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
namespace=hlab-storage

for command in helm kubectl; do
  command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; exit 1; }
done

kubectl get namespace "$namespace" >/dev/null || { echo "Namespace $namespace is missing; install the platform chart with namespaces.storage.enabled=true first." >&2; exit 1; }

helm upgrade --install local-path-provisioner "$chart_dir" --namespace "$namespace" "$@"
