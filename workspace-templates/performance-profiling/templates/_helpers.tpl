{{/*
Create a safe resource name that respects Kubernetes naming limits.
This helper ensures the final name doesn't exceed 63 characters.
Usage: {{ include "performance-profiling.safeName" (dict "base" .Values.deploymentName "suffix" "profiling-config") }}
*/}}
{{- define "performance-profiling.safeName" -}}
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
Create a safe job name specifically for performance-profiling resources.
*/}}
{{- define "performance-profiling.jobName" -}}
{{- .Values.deploymentName | trunc 63 -}}
{{- end -}}

{{/*
Create a safe configmap name specifically for performance-profiling configmap.
*/}}
{{- define "performance-profiling.configmapName" -}}
{{- include "performance-profiling.safeName" (dict "base" .Values.deploymentName "suffix" "prof-config") -}}
{{- end -}}
