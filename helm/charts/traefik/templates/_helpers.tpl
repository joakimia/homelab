{{- define "traefik.fullname" -}}
{{- .Values.name | default .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "traefik.selectorLabels" -}}
app.kubernetes.io/name: {{ include "traefik.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "traefik.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "traefik.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
