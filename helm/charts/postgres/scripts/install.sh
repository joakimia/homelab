#!/usr/bin/env bash
# Installs or upgrades the PostgreSQL release.
# Creates postgres-credentials if missing: each value comes from $<KEY>, else a
# prompt in a terminal (Enter = default or generated), else the default.
# Extra arguments are passed to helm upgrade, for example --values <profile overlay>.
set -euo pipefail
export LC_ALL=C  # English messages from bash and tools, whatever the local language

chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
namespace=hlab-database
# Must match defaultSecrets.credentials.name in values.yaml.
secret_name=postgres-credentials

# Prints $<key>, else typed input (hidden with "hidden"), else the default. Prompts go to stderr.
secret_value() {
  local key=$1 label=$2 default=$3 hidden=${4:-} value=''
  if [[ -n "${!key:-}" ]]; then
    printf '%s' "${!key}"
    return 0
  fi
  if [[ -t 0 ]]; then
    if [[ "$hidden" == hidden ]]; then
      read -r -s -p "$label (Enter = generate): " value
      echo >&2
    else
      read -r -p "$label [$default]: " value
    fi
  fi
  printf '%s' "${value:-$default}"
}

# Creates the Secret if it is missing; never overwrites it.
create_secret() {
  local database user password
  if kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1; then
    echo "Reusing the $secret_name Secret."
    return 0
  fi
  echo "Creating the $secret_name Secret (first install)."
  database="$(secret_value POSTGRES_DB "PostgreSQL database" homelab)"
  user="$(secret_value POSTGRES_USER "PostgreSQL user" homelab)"
  password="$(secret_value POSTGRES_PASSWORD "PostgreSQL password" "$(openssl rand -hex 24)" hidden)"
  kubectl create secret generic "$secret_name" -n "$namespace" \
    --from-literal=POSTGRES_DB="$database" \
    --from-literal=POSTGRES_USER="$user" \
    --from-literal=POSTGRES_PASSWORD="$password" >/dev/null
  echo "Created $secret_name (user: $user, database: $database). Read the password with kubectl, see the README."
}

for command in helm kubectl openssl; do
  command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; exit 1; }
done

kubectl get namespace "$namespace" >/dev/null || { echo "Namespace $namespace is missing; install the platform chart first." >&2; exit 1; }

create_secret
helm upgrade --install postgres "$chart_dir" --namespace "$namespace" "$@"
