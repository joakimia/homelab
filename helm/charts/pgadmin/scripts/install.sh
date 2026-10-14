#!/usr/bin/env bash
# Installs or upgrades the pgAdmin release.
# Creates pgadmin-credentials if missing: each value comes from $<KEY>, else a
# prompt in a terminal (Enter = default or generated), else the default.
# Extra arguments are passed to helm upgrade, for example --values <profile overlay>.
set -euo pipefail
export LC_ALL=C  # English messages from bash and tools, whatever the local language

chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
namespace=hlab-frontend-apps
# Must match defaultSecrets.login.name in values.yaml.
secret_name=pgadmin-credentials

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
  email="$(secret_value PGADMIN_DEFAULT_EMAIL "pgAdmin login email" admin@homelab.com)"
  generated="$(openssl rand -hex 24)"
  password="$(secret_value PGADMIN_DEFAULT_PASSWORD "pgAdmin password" "$generated" hidden)"
  kubectl create secret generic "$secret_name" -n "$namespace" \
    --from-literal=PGADMIN_DEFAULT_EMAIL="$email" \
    --from-literal=PGADMIN_DEFAULT_PASSWORD="$password" >/dev/null
  if [[ "$password" == "$generated" ]]; then
    echo "Created $secret_name. Initial login: $email / $password"
  else
    echo "Created $secret_name. Initial login: $email with the password you chose."
  fi
}

for command in helm kubectl openssl; do
  command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; exit 1; }
done

kubectl get namespace "$namespace" >/dev/null || { echo "Namespace $namespace is missing; install the platform chart first." >&2; exit 1; }

create_secret
helm upgrade --install pgadmin "$chart_dir" --namespace "$namespace" "$@"
