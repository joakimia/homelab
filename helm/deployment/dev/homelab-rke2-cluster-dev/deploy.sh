#!/usr/bin/env bash
# Deploys the charts in deploy-set.json to the RKE2 cluster. Each listed chart's
# scripts/install.sh runs in order with this profile's values overlay and extra Helm flags.
# Each environment/cluster profile keeps its own deploy.sh so the flow can differ per cluster.
# The profile folder name is the cluster name, used for the kubeconfig file and its context.
#
#   ./deploy.sh debian@<vm-ip>               Default, from the Mac: copy the VM's kubeconfig over
#                                            SSH to ./.local/<cluster>.kubeconfig and run Helm here.
#   ./deploy.sh --kubeconfig debian@<vm-ip>  Only refresh .local/<cluster>.kubeconfig (for k9s).
#   ./deploy.sh --local                      Use the current kubectl context; install.sh runs
#                                            this on the VM.
set -euo pipefail
export LC_ALL=C  # English messages from bash and tools, whatever the local language

profile_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cluster_name="$(basename "$profile_dir")"
deploy_set="$profile_dir/deploy-set.json"
charts_dir="$(cd "$profile_dir/../../../charts" && pwd)"
# Written under the directory you run deploy.sh from; .local/ is ignored by Git everywhere.
config_file="$PWD/.local/$cluster_name.kubeconfig"

usage() {
  echo "Usage: $0 debian@<vm-ip> | --kubeconfig debian@<vm-ip> | --local" >&2
  exit 2
}

check_target() {
  [[ "$1" =~ ^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+$ ]] || usage
}

# Copies ~/.kube/config from the VM, points it at the VM address instead of 127.0.0.1, and
# renames its context (and a cluster or user with the same name) to the cluster name.
# The file is separate from the default kubeconfig and ignored by Git (it holds credentials).
fetch_kubeconfig() {
  local target=$1 host=${1##*@} temp_file
  mkdir -p "$(dirname "$config_file")"
  chmod 700 "$(dirname "$config_file")"
  temp_file="$config_file.tmp"
  # shellcheck disable=SC2064 # expand now: temp_file is local and gone when the trap fires
  trap "rm -f '$temp_file'" EXIT
  scp -q "$target:~/.kube/config" "$temp_file"

  if ! HOMELAB_KUBECONFIG_HOST="$host" perl -0pi -e '
    $count = s{^(\s*server:\s*https://)[^/:\s]+(:\d+)?}{$1 . $ENV{HOMELAB_KUBECONFIG_HOST} . ($2 // "")}mge;
    END { exit($count ? 0 : 1) }
  ' "$temp_file"; then
    echo "Could not find an HTTPS Kubernetes API server in the VM kubeconfig" >&2
    exit 1
  fi
  if ! HOMELAB_CLUSTER_NAME="$cluster_name" perl -0pi -e '
    ($old) = /^current-context:[ \t]*(\S+)[ \t]*$/m;
    $count = defined $old ? s{^(\s*(?:-\s+)?(?:name|cluster|user|current-context):[ \t]*)\Q$old\E[ \t]*$}{$1$ENV{HOMELAB_CLUSTER_NAME}}mg : 0;
    END { exit($count ? 0 : 1) }
  ' "$temp_file"; then
    echo "Could not find the current context in the VM kubeconfig" >&2
    exit 1
  fi

  chmod 600 "$temp_file"
  mv "$temp_file" "$config_file"
  trap - EXIT
  echo "Wrote the kubeconfig for $target to $config_file with context $cluster_name (ignored by Git)."
}

deploy_releases() {
  local command count i chart values arg args
  for command in jq helm kubectl; do
    command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; exit 1; }
  done
  jq -e '.releases | type == "array" and length > 0' "$deploy_set" >/dev/null || {
    echo "$deploy_set must have a non-empty releases array." >&2
    exit 1
  }
  # Helm 4 calls it --rollback-on-failure; Helm 3 only knows the older name --atomic.
  local helm_major
  helm_major="$(helm version --template '{{.Version}}' | sed -E 's/^v([0-9]+).*/\1/')"

  echo "Deploying profile $cluster_name to context $(kubectl config current-context) with Helm $(helm version --short)"
  kubectl get nodes >/dev/null

  count="$(jq '.releases | length' "$deploy_set")"
  for ((i = 0; i < count; i++)); do
    chart="$(jq -r ".releases[$i].chart" "$deploy_set")"
    if [[ ! "$chart" =~ ^[a-z0-9-]+$ || ! -x "$charts_dir/$chart/scripts/install.sh" ]]; then
      echo "Release $i: no executable install script for chart '$chart' in $charts_dir." >&2
      exit 1
    fi

    # Overlay defaults to <chart>/values.yaml in the profile; an explicit "values" must exist.
    values="$(jq -r ".releases[$i].values // empty" "$deploy_set")"
    args=()
    if [[ -n "$values" ]]; then
      [[ -f "$profile_dir/$values" ]] || { echo "Values overlay not found: $profile_dir/$values" >&2; exit 1; }
      args+=(--values "$profile_dir/$values")
    elif [[ -f "$profile_dir/$chart/values.yaml" ]]; then
      args+=(--values "$profile_dir/$chart/values.yaml")
    fi

    while IFS= read -r arg; do
      if [[ "$arg" == --rollback-on-failure && "$helm_major" == 3 ]]; then
        arg=--atomic
      fi
      args+=("$arg")
    done < <(jq -r ".defaults.helmArgs // [] | .[]" "$deploy_set"; jq -r ".releases[$i].helmArgs // [] | .[]" "$deploy_set")

    echo
    echo "==> $chart"
    "$charts_dir/$chart/scripts/install.sh" ${args[@]+"${args[@]}"}
  done

  echo
  echo "Deployed releases:"
  helm list -A
  echo
  echo "Ingresses:"
  kubectl get ingress -A
  echo
  echo "Point pgadmin.homelab.com and homepage.homelab.com at the VM IP (DNS or /etc/hosts), then open http://homepage.homelab.com:8080/"
  echo "Without DNS: curl --resolve homepage.homelab.com:8080:<VM-IP> http://homepage.homelab.com:8080/"
}

case "${1:-}" in
  --local)
    [[ $# -eq 1 ]] || usage
    deploy_releases
    ;;
  --kubeconfig)
    [[ $# -eq 2 ]] || usage
    check_target "$2"
    command -v scp >/dev/null || { echo "scp is required" >&2; exit 1; }
    fetch_kubeconfig "$2"
    ;;
  "" | -*)
    usage
    ;;
  *)
    [[ $# -eq 1 ]] || usage
    check_target "$1"
    command -v scp >/dev/null || { echo "scp is required" >&2; exit 1; }
    fetch_kubeconfig "$1"
    export KUBECONFIG="$config_file"
    deploy_releases
    ;;
esac
