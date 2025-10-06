{{/*
Create a safe resource name that respects Kubernetes naming limits.
This helper ensures the final name doesn't exceed 63 characters.
Usage: {{ include "vscode-devcontainer.safeName" (dict "base" .Values.deploymentName "suffix" "code") }}
*/}}
{{- define "vscode-devcontainer.safeName" -}}
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
Create a safe deployment name specifically for vscode-devcontainer resources.
*/}}
{{- define "vscode-devcontainer.deploymentName" -}}
{{- include "vscode-devcontainer.safeName" (dict "base" .Values.deploymentName "suffix" "code") -}}
{{- end -}}

{{/*
Create a safe PVC name specifically for vscode-devcontainer storage.
*/}}
{{- define "vscode-devcontainer.pvcName" -}}
{{- include "vscode-devcontainer.safeName" (dict "base" .Values.deploymentName "suffix" "code-pvc") -}}
{{- end -}}

{{/*
Create a safe volume name for vscode-devcontainer storage.
*/}}
{{- define "vscode-devcontainer.storageVolumeName" -}}
{{- include "vscode-devcontainer.safeName" (dict "base" .Values.deploymentName "suffix" "code-storage") -}}
{{- end -}}
