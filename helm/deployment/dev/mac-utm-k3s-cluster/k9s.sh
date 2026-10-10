#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
KUBECONFIG_FILE="$REPO_ROOT/.local/homelab-kubeconfig"

if [[ ! -f "$KUBECONFIG_FILE" ]]; then
  echo "Missing local MicroK8s kubeconfig: $KUBECONFIG_FILE" >&2
  echo "Copy it from the VM first, then rerun this script." >&2
  exit 1
fi
command -v k9s >/dev/null || { echo "Install k9s on the Mac (for example: brew install k9s)" >&2; exit 1; }

exec env KUBECONFIG="$KUBECONFIG_FILE" k9s --context microk8s "$@"
