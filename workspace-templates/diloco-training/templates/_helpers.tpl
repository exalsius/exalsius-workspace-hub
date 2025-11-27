{{/*
Create a safe resource name that respects Kubernetes naming limits.
This helper ensures the final name doesn't exceed 63 characters.
Usage: {{ include "diloco-training.safeName" (dict "base" .Values.global.deploymentName "suffix" "config") }}
*/}}
{{- define "diloco-training.safeName" -}}
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
Create a safe job name specifically for diloco-training resources.
*/}}
{{- define "diloco-training.jobName" -}}
{{- .Values.global.deploymentName | trunc 63 -}}
{{- end -}}

{{/*
Create a safe configmap name specifically for diloco-training configmap.
*/}}
{{- define "diloco-training.configmapName" -}}
{{- include "diloco-training.safeName" (dict "base" .Values.global.deploymentName "suffix" "config") -}}
{{- end -}}

{{/*
Create etcd service name for rendezvous.
*/}}
{{- define "diloco-training.etcdServiceName" -}}
{{- if .Values.elastic.etcd.externalEndpoint -}}
{{- .Values.elastic.etcd.externalEndpoint -}}
{{- else -}}
{{- printf "%s-etcd" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/*
Create full etcd rendezvous endpoint.
*/}}
{{- define "diloco-training.etcdEndpoint" -}}
{{- if .Values.elastic.etcd.externalEndpoint -}}
{{- .Values.elastic.etcd.externalEndpoint -}}
{{- else -}}
{{- $name := "etcd" -}}
{{- $max := sub 63 (len $name) -}}
{{- $prefix := .Values.global.deploymentName | trunc (int $max) | trimSuffix "-" -}}
{{- printf "%s-%s.%s.svc.cluster.local:2379" $prefix $name .Values.global.deploymentNamespace -}}
{{- end -}}
{{- end -}}

{{/*
Calculate NVIDIA minNodes based on explicit config or distribution policy.
*/}}
{{- define "diloco-training.nvidia.minNodes" -}}
{{- if ne .Values.gpu.nvidia.minNodes nil -}}
{{- .Values.gpu.nvidia.minNodes -}}
{{- else -}}
{{- include "diloco-training.calculateMinNodes" (dict "Values" .Values "gpuType" "nvidia") -}}
{{- end -}}
{{- end -}}

{{/*
Calculate NVIDIA maxNodes based on explicit config or distribution policy.
*/}}
{{- define "diloco-training.nvidia.maxNodes" -}}
{{- if ne .Values.gpu.nvidia.maxNodes nil -}}
{{- .Values.gpu.nvidia.maxNodes -}}
{{- else -}}
{{- include "diloco-training.calculateMaxNodes" (dict "Values" .Values "gpuType" "nvidia") -}}
{{- end -}}
{{- end -}}

{{/*
Calculate AMD minNodes based on explicit config or distribution policy.
*/}}
{{- define "diloco-training.amd.minNodes" -}}
{{- if ne .Values.gpu.amd.minNodes nil -}}
{{- .Values.gpu.amd.minNodes -}}
{{- else -}}
{{- include "diloco-training.calculateMinNodes" (dict "Values" .Values "gpuType" "amd") -}}
{{- end -}}
{{- end -}}

{{/*
Calculate AMD maxNodes based on explicit config or distribution policy.
*/}}
{{- define "diloco-training.amd.maxNodes" -}}
{{- if ne .Values.gpu.amd.maxNodes nil -}}
{{- .Values.gpu.amd.maxNodes -}}
{{- else -}}
{{- include "diloco-training.calculateMaxNodes" (dict "Values" .Values "gpuType" "amd") -}}
{{- end -}}
{{- end -}}

{{/*
Calculate minNodes for a specific GPU type based on distribution policy.
*/}}
{{- define "diloco-training.calculateMinNodes" -}}
{{- $values := .Values -}}
{{- $gpuType := .gpuType -}}
{{- $distribution := $values.elastic.gpuDistribution | default "auto" -}}
{{- $totalMin := int $values.elastic.minNodes -}}
{{- $nvEnabled := $values.gpu.nvidia.enabled -}}
{{- $amdEnabled := $values.gpu.amd.enabled -}}
{{- if eq $distribution "auto" -}}
  {{- if and $nvEnabled $amdEnabled -}}
    {{- if eq $gpuType "nvidia" -}}{{- div $totalMin 2 -}}{{- else -}}{{- sub $totalMin (div $totalMin 2) -}}{{- end -}}
  {{- else if eq $gpuType "nvidia" -}}
    {{- if $nvEnabled -}}{{- $totalMin -}}{{- else -}}0{{- end -}}
  {{- else -}}
    {{- if $amdEnabled -}}{{- $totalMin -}}{{- else -}}0{{- end -}}
  {{- end -}}
{{- else if eq $distribution "prefer-nvidia" -}}
  {{- if eq $gpuType "nvidia" -}}{{- if $nvEnabled -}}{{- $totalMin -}}{{- else -}}0{{- end -}}{{- else -}}0{{- end -}}
{{- else if eq $distribution "prefer-amd" -}}
  {{- if eq $gpuType "amd" -}}{{- if $amdEnabled -}}{{- $totalMin -}}{{- else -}}0{{- end -}}{{- else -}}0{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Calculate maxNodes for a specific GPU type based on distribution policy.
*/}}
{{- define "diloco-training.calculateMaxNodes" -}}
{{- $values := .Values -}}
{{- $gpuType := .gpuType -}}
{{- $distribution := $values.elastic.gpuDistribution | default "auto" -}}
{{- $totalMax := int $values.elastic.maxNodes -}}
{{- $nvEnabled := $values.gpu.nvidia.enabled -}}
{{- $amdEnabled := $values.gpu.amd.enabled -}}
{{- if eq $distribution "auto" -}}
  {{- if and $nvEnabled $amdEnabled -}}
    {{- if eq $gpuType "nvidia" -}}{{- div (add $totalMax 1) 2 -}}{{- else -}}{{- div $totalMax 2 -}}{{- end -}}
  {{- else if eq $gpuType "nvidia" -}}
    {{- if $nvEnabled -}}{{- $totalMax -}}{{- else -}}0{{- end -}}
  {{- else -}}
    {{- if $amdEnabled -}}{{- $totalMax -}}{{- else -}}0{{- end -}}
  {{- end -}}
{{- else if or (eq $distribution "prefer-nvidia") (eq $distribution "prefer-amd") -}}
  {{- if eq $gpuType "nvidia" -}}{{- if $nvEnabled -}}{{- $totalMax -}}{{- else -}}0{{- end -}}{{- else -}}{{- if $amdEnabled -}}{{- $totalMax -}}{{- else -}}0{{- end -}}{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Calculate total minNodes across all GPU types.
*/}}
{{- define "diloco-training.totalMinNodes" -}}
{{- add (int (include "diloco-training.nvidia.minNodes" .)) (int (include "diloco-training.amd.minNodes" .)) -}}
{{- end -}}

{{/*
Calculate total maxNodes across all GPU types.
*/}}
{{- define "diloco-training.totalMaxNodes" -}}
{{- add (int (include "diloco-training.nvidia.maxNodes" .)) (int (include "diloco-training.amd.maxNodes" .)) -}}
{{- end -}}
