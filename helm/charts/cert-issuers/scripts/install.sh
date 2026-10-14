#!/usr/bin/env bash
# Installs the homelab-ca ClusterIssuer, backed by a local CA that is shared by all clusters.
#
#   ./install.sh [helm flags]   Default: create and trust the CA if needed, create the
#                               homelab-ca Secret if missing, then helm upgrade --install.
#   ./install.sh --ca-only      Only create and trust the CA (no cluster).
#
# CA folder: $HOMELAB_CA_DIR, default ./.local/homelab-ca (ignored by Git; keep ca.key private).
set -euo pipefail
export LC_ALL=C  # English messages from bash and tools, whatever the local language

chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
namespace=hlab-platform
secret_name=homelab-ca
ca_dir="${HOMELAB_CA_DIR:-$PWD/.local/homelab-ca}"
# Name constraints: the CA is only valid for these domains. Changing them needs a new CA.
ca_domains="homelab.com home.arpa"
ca_days=3650

usage() {
  echo "Usage: $0 [helm flags] | --ca-only" >&2
  exit 2
}

require() {
  command -v "$1" >/dev/null || { echo "Required command not found: $1" >&2; exit 1; }
}

# Creates ca.key (ECDSA P-256) and a self-signed, name-constrained ca.crt in $ca_dir if missing.
create_ca() {
  local config domain constraints=''
  if [[ -f "$ca_dir/ca.crt" && -f "$ca_dir/ca.key" ]]; then
    return 0
  fi
  if [[ -e "$ca_dir/ca.crt" || -e "$ca_dir/ca.key" ]]; then
    echo "$ca_dir has only one of ca.crt and ca.key; restore the other or remove both." >&2
    exit 1
  fi
  require openssl
  for domain in $ca_domains; do
    constraints="${constraints:+$constraints, }permitted;DNS:$domain"
  done

  mkdir -p "$ca_dir"
  chmod 700 "$ca_dir"
  config="$ca_dir/openssl.cnf.tmp"
  # shellcheck disable=SC2064 # expand now: config is local and gone when the trap fires
  trap "rm -f '$config'" EXIT
  cat > "$config" <<EOF
[req]
distinguished_name = dn
x509_extensions = v3_ca
prompt = no

[dn]
CN = Homelab local CA $(hostname -s) $(date +%Y-%m-%d)
O = homelab

[v3_ca]
basicConstraints = critical, CA:TRUE, pathlen:0
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
nameConstraints = critical, $constraints
EOF
  (umask 077 && openssl ecparam -name prime256v1 -genkey -noout -out "$ca_dir/ca.key")
  openssl req -x509 -new -key "$ca_dir/ca.key" -sha256 -days "$ca_days" -config "$config" -out "$ca_dir/ca.crt"
  rm -f "$config"
  trap - EXIT
  echo "Created the local CA in $ca_dir ($(openssl x509 -noout -subject -in "$ca_dir/ca.crt"))."
  echo "It is valid for $ca_domains only. Keep ca.key private; it is ignored by Git."
  if ! command -v security >/dev/null; then
    echo "Trust $ca_dir/ca.crt on each client (browser or OS store) for HTTPS without warnings."
  fi
}

# On macOS, trusts ca.crt in the System keychain if it is not trusted yet. No-op elsewhere.
trust_ca() {
  local keychain=/Library/Keychains/System.keychain
  command -v security >/dev/null || return 0
  [[ -f "$ca_dir/ca.crt" ]] || return 0
  if security verify-cert -c "$ca_dir/ca.crt" -L -q >/dev/null 2>&1; then
    return 0
  fi
  echo "Adding $ca_dir/ca.crt to the macOS System keychain as a trusted root (asks for your password)..."
  if sudo security add-trusted-cert -d -r trustRoot -k "$keychain" "$ca_dir/ca.crt"; then
    echo "The local CA is trusted. Restart the browser if it still shows a warning."
  else
    echo "Warning: could not trust the CA. Run this once yourself:" >&2
    echo "  sudo security add-trusted-cert -d -r trustRoot -k $keychain '$ca_dir/ca.crt'" >&2
  fi
}

# Creates the CA Secret if missing; warns if the cluster's CA differs from the local one.
create_ca_secret() {
  local cluster_crt
  if kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1; then
    echo "Reusing the $secret_name Secret."
    if [[ -f "$ca_dir/ca.crt" ]]; then
      cluster_crt="$(kubectl get secret "$secret_name" -n "$namespace" -o jsonpath='{.data.tls\.crt}' | base64 --decode)"
      if [[ "$cluster_crt" != "$(cat "$ca_dir/ca.crt")" ]]; then
        echo "Warning: the cluster's $secret_name differs from $ca_dir/ca.crt, so browsers that trust" >&2
        echo "the local CA will warn. To switch: kubectl -n $namespace delete secret $secret_name, rerun." >&2
      fi
    fi
    return 0
  fi
  create_ca
  kubectl create secret tls "$secret_name" -n "$namespace" \
    --cert="$ca_dir/ca.crt" --key="$ca_dir/ca.key" >/dev/null
  echo "Created the $secret_name Secret from $ca_dir."
}

# Needs cert-manager (CRDs and webhook) installed first.
install_release() {
  require helm
  require kubectl
  kubectl get namespace "$namespace" >/dev/null || { echo "Namespace $namespace is missing; install the platform chart with namespaces.platform.enabled=true first." >&2; exit 1; }
  kubectl get crd clusterissuers.cert-manager.io >/dev/null 2>&1 || { echo "cert-manager CRDs are missing; install the cert-manager chart first." >&2; exit 1; }
  create_ca_secret
  trust_ca
  helm upgrade --install cert-issuers "$chart_dir" --namespace "$namespace" "$@"
}

case "${1:-}" in
  --ca-only)
    [[ $# -eq 1 ]] || usage
    create_ca
    trust_ca
    ;;
  -h | --help)
    usage
    ;;
  *)
    install_release "$@"
    ;;
esac
