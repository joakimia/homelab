{{- define "platform.validateValues" -}}
{{- $namespaces := required "namespaces is required" .Values.namespaces -}}
{{- range $key := list "networking" "frontend" "backendApi" "backgroundWorkers" "database" "filestore" "platform" "tools" "observability" -}}
  {{- $namespace := required (printf "namespaces.%s is required" $key) (get $namespaces $key) -}}
  {{- $_ := required (printf "namespaces.%s.name is required" $key) $namespace.name -}}
  {{- $_ := required (printf "namespaces.%s.purpose is required" $key) $namespace.purpose -}}
  {{- $_ := required (printf "namespaces.%s.podSecurityEnforce is required" $key) $namespace.podSecurityEnforce -}}
  {{- if not (hasKey $namespace "enabled") -}}
    {{- fail (printf "namespaces.%s.enabled is required" $key) -}}
  {{- end -}}
{{- end -}}
{{- if .Values.networkPolicies.enabled -}}
  {{- $policies := required "networkPolicies is required when networkPolicies.enabled is true" .Values.networkPolicies -}}
  {{- $dns := required "networkPolicies.dns is required when network policies are enabled" $policies.dns -}}
  {{- $_ := required "networkPolicies.dns.namespace is required" $dns.namespace -}}
  {{- $_ := required "networkPolicies.dns.podSelector is required" $dns.podSelector -}}
  {{- range $key := list "traefik" "pgadmin" "pgbouncer" "postgres" -}}
    {{- $workload := required (printf "networkPolicies.%s is required" $key) (get $policies $key) -}}
    {{- $_ := required (printf "networkPolicies.%s.podSelector is required" $key) $workload.podSelector -}}
  {{- end -}}
{{- end -}}
{{- $storageClass := required "storageClass is required" .Values.storageClass -}}
{{- if not (hasKey $storageClass "enabled") -}}
  {{- fail "storageClass.enabled is required" -}}
{{- end -}}
{{- if $storageClass.enabled -}}
  {{- $_ := required "storageClass.name is required when storageClass.enabled is true" $storageClass.name -}}
  {{- $_ := required "storageClass.provisioner is required when storageClass.enabled is true" $storageClass.provisioner -}}
  {{- $_ := required "storageClass.reclaimPolicy is required when storageClass.enabled is true" $storageClass.reclaimPolicy -}}
  {{- $_ := required "storageClass.volumeBindingMode is required when storageClass.enabled is true" $storageClass.volumeBindingMode -}}
{{- end -}}
{{- end -}}
