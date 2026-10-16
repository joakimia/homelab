#!/usr/bin/env bash
# Installs or upgrades Grafana from the upstream chart pinned in Chart.lock.
# Creates grafana-admin if missing: each value comes from $<KEY>, else a prompt in a
# terminal (Enter = default or generated), else the default.
# Extra arguments are passed to helm upgrade, for example --values <profile overlay>.
set -euo pipefail
export LC_ALL=C  # English messages from bash and tools, whatever the local language

chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
namespace=hlab-observability
# Must match grafana.admin.existingSecret in values.yaml.
secret_name=grafana-admin

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
  local user password generated
  if kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1; then
    echo "Reusing the $secret_name Secret."
    return 0
  fi
  echo "Creating the $secret_name Secret (first install)."
  user="$(secret_value GRAFANA_ADMIN_USER "Grafana admin user" admin)"
  generated="$(openssl rand -hex 24)"
  password="$(secret_value GRAFANA_ADMIN_PASSWORD "Grafana admin password" "$generated" hidden)"
  kubectl create secret generic "$secret_name" -n "$namespace" \
    --from-literal=admin-user="$user" \
    --from-literal=admin-password="$password" >/dev/null
  if [[ "$password" == "$generated" ]]; then
    echo "Created $secret_name. Grafana admin login: $user / $password"
  else
    echo "Created $secret_name. Grafana admin login: $user with the password you chose."
  fi
}

for command in helm kubectl openssl; do
  command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; exit 1; }
done

kubectl get namespace "$namespace" >/dev/null || { echo "Namespace $namespace is missing; install the platform chart with namespaces.observability.enabled=true first." >&2; exit 1; }

create_secret
echo "Fetching the upstream Grafana chart..."
helm dependency build "$chart_dir" >/dev/null

helm upgrade --install grafana "$chart_dir" --namespace "$namespace" "$@"
