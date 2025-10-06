{{/*
Create a safe resource name that respects Kubernetes naming limits.
This helper ensures the final name doesn't exceed 63 characters.
Usage: {{ include "test-workspace.safeName" (dict "base" .Values.deploymentName "suffix" "test") }}
*/}}
{{- define "test-workspace.safeName" -}}
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
Create a safe deployment name specifically for test-workspace resources.
*/}}
{{- define "test-workspace.deploymentName" -}}
{{- include "test-workspace.safeName" (dict "base" .Values.deploymentName "suffix" "test") -}}
{{- end -}}

{{/*
Create a safe service name specifically for test-workspace service.
*/}}
{{- define "test-workspace.serviceName" -}}
{{- include "test-workspace.safeName" (dict "base" .Values.deploymentName "suffix" "test") -}}
{{- end -}}
