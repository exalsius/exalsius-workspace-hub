{{- define "modelService.configMapHash" -}}
{{- toYaml .Values.ms.modelArtifacts | sha256sum | trunc 8 -}}
{{- end -}}