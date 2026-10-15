#!/bin/sh
# Deletes Kubernetes leftovers older than RETENTION_DAYS in the namespaces labelled
# NAMESPACE_LABEL: Failed pods that no Job owns (for example evicted pods) and finished Jobs that
# no CronJob owns. Runs in the periodic-cleanup CronJob (alpine/kubectl, busybox sh); the chart
# puts it in a ConfigMap. DRY_RUN=true only lists what would be deleted.
set -eu
export LC_ALL=C  # English messages from the tools
# Timestamps as digits (20261014203000), so they compare as integers.
now=$(date -u +%s)
cutoff=$(date -u -d "@$((now - RETENTION_DAYS * 86400))" +%Y%m%d%H%M%S)
dry_run=''
if [ "$DRY_RUN" = true ]; then
  dry_run='--dry-run=server'
fi
echo "Deleting leftovers finished before $cutoff UTC (older than $RETENTION_DAYS days, dry run: $DRY_RUN)"
deleted=0

# Deletes kind/name in a namespace when its time is before the cutoff.
delete_if_old() {
  kind=$1 namespace=$2 name=$3 time=$4
  [ -n "$time" ] || return 0
  if [ "$(echo "$time" | tr -dc 0-9)" -lt "$cutoff" ]; then
    kubectl delete "$kind" "$name" -n "$namespace" $dry_run
    deleted=$((deleted + 1))
  fi
}

for namespace in $(kubectl get namespaces -l "$NAMESPACE_LABEL" -o jsonpath='{.items[*].metadata.name}'); do
  kubectl get pods -n "$namespace" --field-selector=status.phase=Failed \
    -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.metadata.ownerReferences[0].kind}{"|"}{.metadata.creationTimestamp}{"\n"}{end}' > /tmp/pods
  while IFS='|' read -r name owner created; do
    [ "$owner" = Job ] || delete_if_old pod "$namespace" "$name" "$created"
  done < /tmp/pods

  kubectl get jobs -n "$namespace" \
    -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.metadata.ownerReferences[0].kind}{"|"}{.status.completionTime}{"|"}{.status.conditions[?(@.type=="Failed")].lastTransitionTime}{"\n"}{end}' > /tmp/jobs
  while IFS='|' read -r name owner completed failed; do
    [ "$owner" = CronJob ] || delete_if_old job "$namespace" "$name" "${completed:-$failed}"
  done < /tmp/jobs
done
echo "Done: $deleted matched (deleted unless dry run)"
