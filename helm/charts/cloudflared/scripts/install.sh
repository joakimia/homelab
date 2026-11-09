#!/usr/bin/env bash
# Installs or upgrades the cloudflared release (the Cloudflare Tunnel connector).
# Creates cloudflared-tunnel if missing, with the tunnel token from $TUNNEL_TOKEN, else a
# hidden prompt in a terminal. Terraform creates the tunnel and its token:
#   tofu -chdir=infratructure/cloudflare/terraform/<env> output -raw tunnel_token
# Extra arguments are passed to helm upgrade, for example --values <profile overlay>.
set -euo pipefail
export LC_ALL=C  # English messages from bash and tools, whatever the local language

chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
namespace=hlab-networking
# Must match defaultSecrets.tunnel in values.yaml.
secret_name=cloudflared-tunnel
secret_key=token

# Creates the Secret if it is missing; never overwrites it. The token goes through a private
# temporary file, not the command line (kubectl cannot always open /dev/stdin, e.g. over SSH).
# token_file is global for the EXIT trap.
create_secret() {
  local token=${TUNNEL_TOKEN:-}
  if kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1; then
    echo "Reusing the $secret_name Secret."
    return 0
  fi
  if [[ -z "$token" && -t 0 ]]; then
    read -r -s -p "Cloudflare Tunnel token (tofu output -raw tunnel_token): " token
    echo >&2
  fi
  [[ -n "$token" ]] || { echo "Set TUNNEL_TOKEN (or run in a terminal) to create the $secret_name Secret." >&2; exit 1; }
  token_file="$(umask 077 && mktemp "${TMPDIR:-/tmp}/cloudflared-token.XXXXXX")"
  trap 'rm -f "$token_file"' EXIT
  printf '%s' "$token" > "$token_file"
  kubectl create secret generic "$secret_name" -n "$namespace" --from-file="$secret_key"="$token_file" >/dev/null
  rm -f "$token_file"
  echo "Created the $secret_name Secret."
}

for command in helm kubectl; do
  command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; exit 1; }
done

kubectl get namespace "$namespace" >/dev/null || { echo "Namespace $namespace is missing; install the platform chart first." >&2; exit 1; }

create_secret
helm upgrade --install cloudflared "$chart_dir" --namespace "$namespace" "$@"
