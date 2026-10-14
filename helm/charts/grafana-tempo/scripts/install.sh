#!/usr/bin/env bash
# Installs or upgrades Tempo from the upstream chart pinned in Chart.lock.
# Extra arguments are passed to helm upgrade, for example --values <profile overlay>.
set -euo pipefail
export LC_ALL=C  # English messages from bash and tools, whatever the local language

chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
namespace=hlab-observability

for command in helm kubectl; do
  command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; exit 1; }
done

kubectl get namespace "$namespace" >/dev/null || { echo "Namespace $namespace is missing; install the platform chart with namespaces.observability.enabled=true first." >&2; exit 1; }

echo "Fetching the upstream Tempo chart..."
helm dependency build "$chart_dir" >/dev/null

helm upgrade --install grafana-tempo "$chart_dir" --namespace "$namespace" "$@"
