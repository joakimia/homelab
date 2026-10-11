#!/usr/bin/env bash
# Installs or upgrades the PgBouncer release. Uses the postgres-credentials Secret that the
# postgres chart's install script creates, so install postgres first.
# Extra arguments are passed to helm upgrade, for example --values <profile overlay>.
set -euo pipefail
export LC_ALL=C  # English messages from bash and tools, whatever the local language

chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
namespace=hlab-database

for command in helm kubectl; do
  command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; exit 1; }
done

kubectl get secret postgres-credentials -n "$namespace" >/dev/null || {
  echo "Missing Secret postgres-credentials in $namespace; install the postgres chart first." >&2
  exit 1
}

helm upgrade --install pgbouncer "$chart_dir" --namespace "$namespace" "$@"
