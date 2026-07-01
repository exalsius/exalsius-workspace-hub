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

{{/*
Route rules that match this model (by the trusted X-Gateway-Model-Name header)
and forward to its InferencePool. Shared by the external and internal HTTPRoutes
so the two listeners route identically — they differ only in whether the
external API-key policy is attached.
*/}}
{{- define "llm-d-model.modelRouteRules" -}}
- timeouts:
    request: {{ .Values.httpRequestTimeout }}
  matches:
    - headers:
        - name: X-Gateway-Model-Name
          type: Exact
          value: {{ .Values.ms.modelArtifacts.name }}
      path:
        type: PathPrefix
        value: /v1
  backendRefs:
    - group: inference.networking.k8s.io
      kind: InferencePool
      name: {{ .Release.Name }}
      weight: 1
{{- end -}}