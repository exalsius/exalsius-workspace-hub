{{/*
Create a safe resource name that respects Kubernetes naming limits.
This helper ensures the final name doesn't exceed 63 characters.
Usage: {{ include "vscode-devcontainer.safeName" (dict "base" .Values.global.deploymentName "suffix" "code") }}
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
{{- include "vscode-devcontainer.safeName" (dict "base" .Values.global.deploymentName "suffix" "code") -}}
{{- end -}}

{{/*
Create a safe PVC name specifically for vscode-devcontainer storage.
*/}}
{{- define "vscode-devcontainer.pvcName" -}}
{{- include "vscode-devcontainer.safeName" (dict "base" .Values.global.deploymentName "suffix" "code-pvc") -}}
{{- end -}}

{{/*
Create a safe volume name for vscode-devcontainer storage.
*/}}
{{- define "vscode-devcontainer.storageVolumeName" -}}
{{- include "vscode-devcontainer.safeName" (dict "base" .Values.global.deploymentName "suffix" "code-storage") -}}
{{- end -}}

{{/*
Create a safe service name specifically for vscode-devcontainer service.
*/}}
{{- define "vscode-devcontainer.serviceName" -}}
{{- include "vscode-devcontainer.safeName" (dict "base" .Values.global.deploymentName "suffix" "code") -}}
{{- end -}}

{{/*
Create a safe secret name specifically for vscode-devcontainer secret.
*/}}
{{- define "vscode-devcontainer.secretName" -}}
{{- include "vscode-devcontainer.safeName" (dict "base" .Values.global.deploymentName "suffix" "code-secret") -}}
{{- end -}}

{{/*
Create a safe configmap name specifically for vscode-devcontainer configmap.
*/}}
{{- define "vscode-devcontainer.configmapName" -}}
{{- include "vscode-devcontainer.safeName" (dict "base" .Values.global.deploymentName "suffix" "code-configmap") -}}
{{- end -}}

{{/*
Determine the image to use based on deploymentImage or gpuVendor.
If deploymentImage is provided, use it. Otherwise, auto-select based on gpuVendor.
*/}}
{{- define "vscode-devcontainer.image" -}}
{{- if .Values.deploymentImage -}}
{{- .Values.deploymentImage -}}
{{- else if eq (lower .Values.gpuVendor) "nvidia" -}}
ghcr.io/exalsius/devpod:latest-nvidia-pytorch
{{- else if eq (lower .Values.gpuVendor) "amd" -}}
ghcr.io/exalsius/devpod:latest-rocm-pytorch
{{- else -}}
ghcr.io/exalsius/devpod:latest-nvidia-pytorch
{{- end -}}
{{- end -}}
