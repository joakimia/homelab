{{/*
Container env, Secret env vars, and Secret file mounts from defaultEnv/env (ENV_VAR: value) and
defaultSecrets/secrets (<purpose>: {name, env: {ENV_VAR: key}, mountPath, keys: [key]});
env and secrets override or add. Values may use templates. At install, every Secret and the
keys it is used with must exist.
*/}}
{{- define "homelab.secrets" -}}
{{- toYaml (mergeOverwrite (deepCopy (.Values.defaultSecrets | default dict)) (deepCopy (.Values.secrets | default dict))) -}}
{{- end -}}

{{- define "homelab.containerEnv" -}}
{{- $root := . -}}
{{- $env := merge (deepCopy (.Values.env | default dict)) (.Values.defaultEnv | default dict) -}}
{{- $secrets := include "homelab.secrets" . | fromYaml -}}
{{- range $name, $value := .Values.env -}}
  {{- if or (kindIs "invalid" $value) (eq (toString $value) "") -}}
    {{- fail (printf "env.%s is empty; give it a value or leave it out" $name) -}}
  {{- end -}}
{{- end -}}
{{- $seen := dict -}}
{{- range $name, $value := $env -}}
  {{- if or (kindIs "invalid" $value) (eq (toString $value) "") -}}
    {{- fail (printf "env %s is empty; set it in defaultEnv or env" $name) -}}
  {{- end -}}
  {{- $_ := set $seen $name "env" -}}
{{- end -}}
{{- range $purpose, $secret := $secrets -}}
  {{- if not $secret.name -}}
    {{- fail (printf "secrets.%s.name is required (defaultSecrets or secrets)" $purpose) -}}
  {{- end -}}
  {{- if not (or $secret.env $secret.mountPath) -}}
    {{- fail (printf "secrets.%s needs env (ENV_VAR: key) or mountPath" $purpose) -}}
  {{- end -}}
  {{- range $name, $key := $secret.env -}}
    {{- if not $key -}}
      {{- fail (printf "secrets.%s.env.%s needs the key in Secret %s" $purpose $name $secret.name) -}}
    {{- end -}}
    {{- if hasKey $seen $name -}}
      {{- fail (printf "%s is set twice: in %s and in secrets.%s" $name (get $seen $name) $purpose) -}}
    {{- end -}}
    {{- $_ := set $seen $name (printf "secrets.%s" $purpose) -}}
  {{- end -}}
{{- end -}}
{{- if lookup "v1" "Namespace" "" "kube-system" -}}
  {{- range $purpose, $secret := $secrets -}}
    {{- $existing := lookup "v1" "Secret" $root.Values.namespace $secret.name -}}
    {{- if not $existing -}}
      {{- fail (printf "Secret %s/%s (secrets.%s) is missing; create it first (the chart's own Secrets come from scripts/install.sh)" $root.Values.namespace $secret.name $purpose) -}}
    {{- end -}}
    {{- range $key := concat (values ($secret.env | default dict)) ($secret.keys | default list) -}}
      {{- if not (hasKey ($existing.data | default dict) $key) -}}
        {{- fail (printf "Secret %s/%s has no key %s (secrets.%s)" $root.Values.namespace $secret.name $key $purpose) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- range $name, $value := $env }}
- name: {{ $name }}
  value: {{ tpl (toString $value) $root | quote }}
{{- end }}
{{- range $purpose, $secret := $secrets }}
{{- range $name, $key := $secret.env }}
- name: {{ $name }}
  valueFrom:
    secretKeyRef:
      name: {{ $secret.name }}
      key: {{ $key }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "homelab.secretVolumeMounts" -}}
{{- range $purpose, $secret := include "homelab.secrets" . | fromYaml }}
{{- if $secret.mountPath }}
- name: secret-{{ $purpose }}
  mountPath: {{ $secret.mountPath }}
  readOnly: true
{{- end }}
{{- end }}
{{- end -}}

{{- define "homelab.secretVolumes" -}}
{{- range $purpose, $secret := include "homelab.secrets" . | fromYaml }}
{{- if $secret.mountPath }}
- name: secret-{{ $purpose }}
  secret:
    secretName: {{ $secret.name }}
{{- end }}
{{- end }}
{{- end -}}
