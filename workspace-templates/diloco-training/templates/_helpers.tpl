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
