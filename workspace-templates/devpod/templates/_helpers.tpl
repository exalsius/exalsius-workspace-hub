{{/*
Resource names derive from the Helm release name, which the operator sets to
`wsd-<clusterdeployment>-<workspace>`. The routing provider looks for a Service
named `<release>-<endpoint>`, so naming off .Release.Name keeps the chart and
the operator's routing in lockstep with no hardcoded label keys.
*/}}

{{/*
Common labels.
*/}}
{{- define "devpod.labels" -}}
app.kubernetes.io/name: devpod
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{/*
Selector labels — also the Service selector and pod label.
*/}}
{{- define "devpod.selectorLabels" -}}
app: {{ .Release.Name }}
{{- end -}}

{{/*
Fully-qualified container image reference, selected by the operator-injected GPU
vendor (docs/adr/0003): the ROCm-baked `image.amd` for AMD, else the
framework-free `image.default` (NVIDIA + CPU). Each variant is pinned by digest
and decoupled from the chart version (docs/adr/0001); renders
`repository:tag@digest` when a digest is set, `repository:tag` otherwise.
*/}}
{{- define "devpod.image" -}}
{{- $exPer := (((.Values._exalsius | default dict).resources | default dict).perReplica) | default dict -}}
{{- $img := .Values.image.default -}}
{{- if and (eq (lower (toString ($exPer.gpuVendor | default ""))) "amd") .Values.image.amd -}}
{{- $img = .Values.image.amd -}}
{{- end -}}
{{- printf "%s:%s" $img.repository $img.tag -}}
{{- if $img.digest }}{{- printf "@%s" $img.digest -}}{{- end -}}
{{- end -}}
