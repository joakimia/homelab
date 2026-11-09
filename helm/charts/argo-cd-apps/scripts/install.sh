#!/usr/bin/env bash
# Installs or upgrades the ApplicationSet that lets Argo CD deploy a cluster profile. Needs the
# argo-cd chart (CRDs) first. The profile overlay sets profilePath; deploy.sh --revision <ref>
# passes --set revision=<ref>.
# Extra arguments are passed to helm upgrade, for example --values <profile overlay>.
set -euo pipefail
export LC_ALL=C  # English messages from bash and tools, whatever the local language

chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
namespace=hlab-gitops

for command in helm kubectl; do
  command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; exit 1; }
done

kubectl get namespace "$namespace" >/dev/null || { echo "Namespace $namespace is missing; install the platform chart with namespaces.gitops.enabled=true first." >&2; exit 1; }
kubectl get crd applicationsets.argoproj.io >/dev/null 2>&1 || { echo "Argo CD CRDs are missing; install the argo-cd chart first." >&2; exit 1; }

helm upgrade --install argo-cd-apps "$chart_dir" --namespace "$namespace" "$@"
