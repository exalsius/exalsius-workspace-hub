{{/*
Resource names derive from the Helm release name, which the operator sets to
`wsd-<clusterdeployment>-<workspace>`. The routing provider looks for a Service
named `<release>-<endpoint>`, so naming off .Release.Name keeps the
chart and the operator's routing in lockstep with no hardcoded label keys.
*/}}

{{/*
Common labels.
*/}}
{{- define "marimo.labels" -}}
app.kubernetes.io/name: marimo
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{/*
Selector labels — also the Service selector and pod label.
*/}}
{{- define "marimo.selectorLabels" -}}
app: {{ .Release.Name }}
{{- end -}}

{{/*
Fully-qualified container image reference. Pinned by digest (immutable) and
decoupled from the chart version (see docs/adr/0001). Renders
`repository:tag@digest` when a digest is set, `repository:tag` otherwise.
*/}}
{{- define "marimo.image" -}}
{{- $img := .Values.image -}}
{{- printf "%s:%s" $img.repository $img.tag -}}
{{- if $img.digest }}{{- printf "@%s" $img.digest -}}{{- end -}}
{{- end -}}
