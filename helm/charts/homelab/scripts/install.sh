#!/usr/bin/env bash
# Installs or upgrades the homelab release: the homelab's own apps from the base charts.
# Resources use the namespaces in the values; the release record is kept in default.
# Extra arguments are passed to helm upgrade, for example --values <profile overlay>.
set -euo pipefail
export LC_ALL=C  # English messages from bash and tools, whatever the local language

chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for command in helm kubectl; do
  command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; exit 1; }
done

for namespace in hlab-frontend-apps hlab-tools; do
  kubectl get namespace "$namespace" >/dev/null || { echo "Namespace $namespace is missing; install the platform chart first." >&2; exit 1; }
done

# The homepage used to be its own release; Helm will not adopt resources another release owns.
if helm status homepage --namespace hlab-frontend-apps >/dev/null 2>&1; then
  echo "The old homepage release still owns the homepage resources. Remove it first (the page is down until this install finishes):" >&2
  echo "  helm uninstall homepage --namespace hlab-frontend-apps" >&2
  exit 1
fi

echo "Packaging the base charts..."
helm dependency build "$chart_dir" >/dev/null

helm upgrade --install homelab "$chart_dir" --namespace default "$@"
