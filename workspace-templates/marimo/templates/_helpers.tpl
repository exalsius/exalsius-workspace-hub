{{/*
Create a safe resource name that respects Kubernetes naming limits.
This helper ensures the final name doesn't exceed 63 characters.
Usage: {{ include "marimo.safeName" (dict "base" .Values.global.deploymentName "suffix" "marimo") }}
*/}}
{{- define "marimo.safeName" -}}
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
Create a safe deployment name specifically for marimo resources.
*/}}
{{- define "marimo.deploymentName" -}}
{{- include "marimo.safeName" (dict "base" .Values.global.deploymentName "suffix" "marimo") -}}
{{- end -}}

{{/*
Create a safe service name specifically for marimo service.
*/}}
{{- define "marimo.serviceName" -}}
{{- include "marimo.safeName" (dict "base" .Values.global.deploymentName "suffix" "marimo") -}}
{{- end -}}

{{/*
Create a safe PVC name specifically for marimo storage.
*/}}
{{- define "marimo.pvcName" -}}
{{- include "marimo.safeName" (dict "base" .Values.global.deploymentName "suffix" "marimo-pvc") -}}
{{- end -}}

{{/*
Create a safe secret name specifically for marimo secret.
*/}}
{{- define "marimo.secretName" -}}
{{- include "marimo.safeName" (dict "base" .Values.global.deploymentName "suffix" "marimo-secret") -}}
{{- end -}}

{{/*
Create a safe volume name for marimo storage.
*/}}
{{- define "marimo.storageVolumeName" -}}
{{- include "marimo.safeName" (dict "base" .Values.global.deploymentName "suffix" "marimo-storage") -}}
{{- end -}}
