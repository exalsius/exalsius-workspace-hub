{{- define "modelService.configMapHash" -}}
{{- toYaml .Values.ms.modelArtifacts | sha256sum | trunc 8 -}}
{{- end -}}

{{/*
Common labels.
*/}}
{{- define "llm-d-model.labels" -}}
app.kubernetes.io/name: llm-d-model
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{/*
Selector labels — also the Service selector and pod label.
*/}}
{{- define "llm-d-model.selectorLabels" -}}
inferencepool: {{ .Release.Name }}-epp
{{- end -}}