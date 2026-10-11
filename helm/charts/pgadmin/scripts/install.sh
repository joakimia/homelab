#!/usr/bin/env bash
# Installs or upgrades the pgAdmin release. Creates the pgadmin-credentials Secret on first
# install and prints the initial login once. Set PGADMIN_DEFAULT_EMAIL to change the login.
# Extra arguments are passed to helm upgrade, for example --values <profile overlay>.
set -euo pipefail
export LC_ALL=C  # English messages from bash and tools, whatever the local language

chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
namespace=hlab-frontend-apps
email="${PGADMIN_DEFAULT_EMAIL:-admin@homelab.com}"

for command in helm kubectl openssl; do
  command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; exit 1; }
done

kubectl get namespace "$namespace" >/dev/null || { echo "Namespace $namespace is missing; install the platform chart first." >&2; exit 1; }

if ! kubectl get secret pgadmin-credentials -n "$namespace" >/dev/null 2>&1; then
  password="$(openssl rand -hex 24)"
  kubectl create secret generic pgadmin-credentials -n "$namespace" \
    --from-literal=PGADMIN_DEFAULT_EMAIL="$email" \
    --from-literal=PGADMIN_DEFAULT_PASSWORD="$password" >/dev/null
  echo "Created pgAdmin login Secret. Initial login: $email / $password"
  unset password
else
  echo "Reusing pgAdmin credentials Secret."
fi

helm upgrade --install pgadmin "$chart_dir" --namespace "$namespace" "$@"
