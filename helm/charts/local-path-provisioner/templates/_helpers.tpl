{{- define "local-path-provisioner.fullname" -}}
{{- .Values.name | default .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "local-path-provisioner.selectorLabels" -}}
app.kubernetes.io/name: {{ include "local-path-provisioner.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "local-path-provisioner.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "local-path-provisioner.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
