{{/*
Resource names derive from the Helm release name, which the operator sets to
`wsd-<clusterdeployment>-<workspace>`. The routing provider looks for a Service
named `<release>-<endpoint>`, so naming off .Release.Name keeps the
chart and the operator's routing in lockstep with no hardcoded label keys.
*/}}

{{/*
Common labels.
*/}}
{{- define "jupyter-notebook.labels" -}}
app.kubernetes.io/name: jupyter-notebook
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{/*
Selector labels — also the Service selector and pod label.
*/}}
{{- define "jupyter-notebook.selectorLabels" -}}
app: {{ .Release.Name }}
{{- end -}}
