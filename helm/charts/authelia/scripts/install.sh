#!/usr/bin/env bash
# Installs or upgrades the Authelia release.
# Creates the authelia Secret if missing: generated JWT, session, and storage keys, and a users
# file with one admin. Each value comes from $<NAME>, else a prompt in a terminal (Enter =
# default or generated), else the default. A generated password is printed once.
# Extra arguments are passed to helm upgrade, for example --values <profile overlay>.
set -euo pipefail
export LC_ALL=C  # English messages from bash and tools, whatever the local language

chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
namespace=hlab-platform
# Must match defaultSecrets.authelia.name in values.yaml.
secret_name=authelia

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
  local user email password generated hash
  if kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1; then
    echo "Reusing the $secret_name Secret."
    return 0
  fi
  # SHA-512 crypt, which Authelia accepts; needs OpenSSL 1.1.1 or later.
  openssl passwd -6 -salt check check >/dev/null 2>&1 || { echo "openssl passwd -6 is not supported; use OpenSSL 1.1.1 or later." >&2; exit 1; }

  echo "Creating the $secret_name Secret (first install)."
  user="$(secret_value AUTHELIA_ADMIN_USER "Authelia admin user" admin)"
  [[ "$user" =~ ^[a-zA-Z0-9._-]+$ ]] || { echo "Invalid user name: $user" >&2; exit 1; }
  email="$(secret_value AUTHELIA_ADMIN_EMAIL "Authelia admin email" admin@homelab.com)"
  generated="$(openssl rand -hex 16)"
  password="$(secret_value AUTHELIA_ADMIN_PASSWORD "Authelia admin password" "$generated" hidden)"
  hash="$(printf '%s' "$password" | openssl passwd -6 -stdin)"

  kubectl create secret generic "$secret_name" -n "$namespace" \
    --from-literal=JWT_SECRET="$(secret_value JWT_SECRET "" "$(openssl rand -hex 32)" </dev/null)" \
    --from-literal=SESSION_SECRET="$(secret_value SESSION_SECRET "" "$(openssl rand -hex 32)" </dev/null)" \
    --from-literal=STORAGE_ENCRYPTION_KEY="$(secret_value STORAGE_ENCRYPTION_KEY "" "$(openssl rand -hex 32)" </dev/null)" \
    --from-literal=users_database.yml="users:
  $user:
    displayname: \"$user\"
    email: \"$email\"
    password: \"$hash\"
    groups: [admins]
" >/dev/null
  if [[ "$password" == "$generated" ]]; then
    echo "Created $secret_name. Login: $user / $password"
  else
    echo "Created $secret_name. Login: $user with the password you chose."
  fi
}

for command in helm kubectl openssl; do
  command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; exit 1; }
done

kubectl get namespace "$namespace" >/dev/null || { echo "Namespace $namespace is missing; install the platform chart with namespaces.platform.enabled=true first." >&2; exit 1; }

create_secret
helm upgrade --install authelia "$chart_dir" --namespace "$namespace" "$@"
