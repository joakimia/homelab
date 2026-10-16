#!/usr/bin/env bash
# Installs or upgrades Alloy from the upstream chart pinned in Chart.lock.
# Extra arguments are passed to helm upgrade, for example --values <profile overlay>.
set -euo pipefail
export LC_ALL=C  # English messages from bash and tools, whatever the local language

chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
namespace=hlab-observability

for command in helm kubectl; do
  command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; exit 1; }
done

kubectl get namespace "$namespace" >/dev/null || { echo "Namespace $namespace is missing; install the platform chart with namespaces.observability.enabled=true first." >&2; exit 1; }

# helm dependency build needs the HTTPS repository registered (OCI charts do not).
helm repo list 2>/dev/null | grep -q "https://grafana.github.io/helm-charts" || helm repo add grafana https://grafana.github.io/helm-charts >/dev/null

echo "Fetching the upstream Alloy chart..."
helm dependency build "$chart_dir" >/dev/null

helm upgrade --install grafana-alloy "$chart_dir" --namespace "$namespace" "$@"
