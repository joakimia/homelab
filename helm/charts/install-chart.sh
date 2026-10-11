#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <platform|traefik|homepage|postgres|pgbouncer|pgadmin>" >&2
  exit 2
fi

chart="$1"
shift
charts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$charts_dir/../.." && pwd)"
chart_dir="$charts_dir/$chart"
profile="${HOMELAB_PROFILE:-dev/mac-utm-k3s-cluster}"
values_file="$repo_root/helm/deployment/$profile/$chart/values.yaml"

case "$chart" in
  platform) namespace=default ;;
  traefik) namespace=hlab-networking ;;
  homepage|pgadmin) namespace=hlab-frontend-apps ;;
  postgres|pgbouncer) namespace=hlab-database ;;
  *) echo "Unknown chart: $chart" >&2; exit 2 ;;
esac

command -v helm >/dev/null || { echo "helm is required on PATH" >&2; exit 1; }
command -v kubectl >/dev/null || { echo "kubectl is required on PATH" >&2; exit 1; }
kubectl get nodes >/dev/null

case "$chart" in
  postgres|pgbouncer)
    kubectl get secret postgres-credentials -n hlab-database >/dev/null || {
      echo "Missing Secret postgres-credentials in hlab-database; run the dev install.sh first." >&2
      exit 1
    }
    ;;
  pgadmin)
    kubectl get secret pgadmin-credentials -n hlab-frontend-apps >/dev/null || {
      echo "Missing Secret pgadmin-credentials in hlab-frontend-apps; run the dev install.sh first." >&2
      exit 1
    }
    ;;
esac

args=(upgrade --install "$chart" "$chart_dir" --namespace "$namespace")

if [[ -f "$values_file" ]]; then
  args+=(--values "$values_file")
fi

args+=("$@")
helm "${args[@]}"
