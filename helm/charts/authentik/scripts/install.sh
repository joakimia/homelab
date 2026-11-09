#!/usr/bin/env bash
# Installs or upgrades authentik from the upstream chart pinned in Chart.lock.
# Creates authentik-credentials if missing: a generated secret key, and the bootstrap admin
# (akadmin) email and password from $<KEY>, else a prompt in a terminal (Enter = default or
# generated), else the default. Copies the database password from the postgres chart's
# Secret into authentik-postgres if missing.
# Extra arguments are passed to helm upgrade, for example --values <profile overlay>.
set -euo pipefail
export LC_ALL=C  # English messages from bash and tools, whatever the local language

chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
namespace=hlab-platform
# Must match the secretKeyRef names in authentik.global.env in values.yaml.
secret_name=authentik-credentials
db_secret_name=authentik-postgres
# Must match roles.authentik.passwordSecret in the postgres profile overlay.
postgres_namespace=hlab-database
postgres_secret_name=postgres-authentik

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

# Creates the Secret if it is missing; never overwrites it. Prints the login once.
create_secret() {
  local email password generated
  if kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1; then
    echo "Reusing the $secret_name Secret."
    return 0
  fi
  echo "Creating the $secret_name Secret (first install)."
  email="$(secret_value AUTHENTIK_BOOTSTRAP_EMAIL "authentik admin email" admin@homelab.com)"
  generated="$(openssl rand -hex 24)"
  password="$(secret_value AUTHENTIK_BOOTSTRAP_PASSWORD "authentik admin password" "$generated" hidden)"
  kubectl create secret generic "$secret_name" -n "$namespace" \
    --from-literal=secret-key="$(openssl rand -base64 48 | tr -d '\n')" \
    --from-literal=bootstrap-email="$email" \
    --from-literal=bootstrap-password="$password" >/dev/null
  if [[ "$password" == "$generated" ]]; then
    echo "Created $secret_name. authentik admin login: akadmin / $password"
  else
    echo "Created $secret_name. authentik admin login: akadmin with the password you chose."
  fi
}

# Copies the authentik role's password from the postgres chart's Secret if it is missing.
copy_db_secret() {
  local password
  if kubectl get secret "$db_secret_name" -n "$namespace" >/dev/null 2>&1; then
    echo "Reusing the $db_secret_name Secret."
    return 0
  fi
  password="$(kubectl get secret "$postgres_secret_name" -n "$postgres_namespace" -o jsonpath='{.data.PASSWORD}' 2>/dev/null | openssl base64 -d -A || true)"
  if [[ -z "$password" ]]; then
    echo "Secret $postgres_namespace/$postgres_secret_name (key PASSWORD) is missing; add roles.authentik and databases.authentik to the postgres overlay and deploy postgres first." >&2
    exit 1
  fi
  kubectl create secret generic "$db_secret_name" -n "$namespace" --from-literal=PASSWORD="$password" >/dev/null
  echo "Created $db_secret_name from $postgres_namespace/$postgres_secret_name."
}

for command in helm kubectl openssl; do
  command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; exit 1; }
done

kubectl get namespace "$namespace" >/dev/null || { echo "Namespace $namespace is missing; install the platform chart with namespaces.platform.enabled=true first." >&2; exit 1; }

copy_db_secret
create_secret
echo "Fetching the upstream authentik chart..."
helm dependency build "$chart_dir" >/dev/null

helm upgrade --install authentik "$chart_dir" --namespace "$namespace" "$@"
