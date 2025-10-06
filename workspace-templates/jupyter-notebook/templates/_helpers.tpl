{{/*
Create a safe resource name that respects Kubernetes naming limits.
This helper ensures the final name doesn't exceed 63 characters.
Usage: {{ include "jupyter-notebook.safeName" (dict "base" .Values.deploymentName "suffix" "notebook-configmap") }}
*/}}
{{- define "jupyter-notebook.safeName" -}}
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
Create a safe deployment name specifically for jupyter-notebook resources.
*/}}
{{- define "jupyter-notebook.deploymentName" -}}
{{- include "jupyter-notebook.safeName" (dict "base" .Values.deploymentName "suffix" "notebook") -}}
{{- end -}}

{{/*
Create a safe configmap name specifically for jupyter-notebook configmap.
*/}}
{{- define "jupyter-notebook.configmapName" -}}
{{- include "jupyter-notebook.safeName" (dict "base" .Values.deploymentName "suffix" "nb-configmap") -}}
{{- end -}}

{{/*
Create a safe PVC name specifically for jupyter-notebook storage.
*/}}
{{- define "jupyter-notebook.pvcName" -}}
{{- include "jupyter-notebook.safeName" (dict "base" .Values.deploymentName "suffix" "nb-pvc") -}}
{{- end -}}

{{/*
Create a safe service name specifically for jupyter-notebook service.
*/}}
{{- define "jupyter-notebook.serviceName" -}}
{{- include "jupyter-notebook.safeName" (dict "base" .Values.deploymentName "suffix" "notebook") -}}
{{- end -}}

{{/*
Create a safe volume name for notebook storage.
*/}}
{{- define "jupyter-notebook.storageVolumeName" -}}
{{- include "jupyter-notebook.safeName" (dict "base" .Values.deploymentName "suffix" "nb-storage") -}}
{{- end -}}

{{/*
Create a safe volume name for configmap volume.
*/}}
{{- define "jupyter-notebook.configmapVolumeName" -}}
{{- include "jupyter-notebook.safeName" (dict "base" .Values.deploymentName "suffix" "cm-volume") -}}
{{- end -}}
