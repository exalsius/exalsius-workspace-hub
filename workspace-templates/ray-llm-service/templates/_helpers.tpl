{{/*
Create a safe resource name that respects Kubernetes naming limits.
This helper ensures the final name doesn't exceed 63 characters.
Usage: {{ include "ray-llm-service.safeName" (dict "base" .Values.global.deploymentName "suffix" "ray-service") }}
*/}}
{{- define "ray-llm-service.safeName" -}}
{{- $base := .base -}}
{{- $suffix := .suffix -}}
{{- $fullSuffix := printf "-%s" $suffix -}}
{{- $maxBaseLength := sub 63 (len $fullSuffix) -}}
{{- if gt (len $base) $maxBaseLength -}}
{{- $truncatedBase := $base | trunc (int $maxBaseLength) -}}
{{- printf "%s%s" $truncatedBase $fullSuffix -}}
{{- else -}}
{{- printf "%s%s" $base $fullSuffix -}}
{{- end -}}
{{- end -}}

{{/*
Create a safe deployment name specifically for ray-llm-service resources.
*/}}
{{- define "ray-llm-service.deploymentName" -}}
{{- include "ray-llm-service.safeName" (dict "base" .Values.global.deploymentName "suffix" "ray-service") -}}
{{- end -}}

{{/*
Create a safe configmap name specifically for ray-llm-service configmap.
*/}}
{{- define "ray-llm-service.configmapName" -}}
{{- include "ray-llm-service.safeName" (dict "base" .Values.global.deploymentName "suffix" "ray-config") -}}
{{- end -}}

{{/*
Create a safe secret name specifically for ray-llm-service secret.
*/}}
{{- define "ray-llm-service.secretName" -}}
{{- include "ray-llm-service.safeName" (dict "base" .Values.global.deploymentName "suffix" "ray-hf-secret") -}}
{{- end -}}

{{/*
Create a safe service name for ray standalone serve service.
*/}}
{{- define "ray-llm-service.serveServiceName" -}}
{{- include "ray-llm-service.safeName" (dict "base" .Values.global.deploymentName "suffix" "ray-serve-svc") -}}
{{- end -}}

{{/*
Create a safe service name for ray standalone dashboard service.
*/}}
{{- define "ray-llm-service.dashboardServiceName" -}}
{{- include "ray-llm-service.safeName" (dict "base" .Values.global.deploymentName "suffix" "ray-dash-svc") -}}
{{- end -}}
