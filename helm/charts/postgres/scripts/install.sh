#!/usr/bin/env bash
# Installs or upgrades the PostgreSQL release. Creates the postgres-credentials Secret on
# first install; reruns keep the existing password.
# Extra arguments are passed to helm upgrade, for example --values <profile overlay>.
set -euo pipefail
export LC_ALL=C  # English messages from bash and tools, whatever the local language

chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
namespace=hlab-database
db_user=homelab
db_name=homelab

for command in helm kubectl openssl; do
  command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; exit 1; }
done

kubectl get namespace "$namespace" >/dev/null || { echo "Namespace $namespace is missing; install the platform chart first." >&2; exit 1; }

if ! kubectl get secret postgres-credentials -n "$namespace" >/dev/null 2>&1; then
  kubectl create secret generic postgres-credentials -n "$namespace" \
    --from-literal=POSTGRES_DB="$db_name" \
    --from-literal=POSTGRES_USER="$db_user" \
    --from-literal=POSTGRES_PASSWORD="$(openssl rand -hex 24)" >/dev/null
  echo "Created PostgreSQL credentials Secret (user: $db_user, database: $db_name)."
else
  echo "Reusing PostgreSQL credentials Secret."
fi

helm upgrade --install postgres "$chart_dir" --namespace "$namespace" "$@"
