{{/*
Common labels.
*/}}
{{- define "llm-d-infra.labels" -}}
app.kubernetes.io/name: llm-d-infra
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{/*
Fixed, not release-relative: models in other namespaces and other Helm releases
attach to this Gateway by name. Mirrors ow.fullnameOverride.
*/}}
{{- define "llm-d-infra.gatewayName" -}}
{{ .Values.gateway.name }}
{{- end -}}
