{{/*
Pod spec for one model-server pod, shared by the leader and worker templates.
Call with: (dict "ctx" $ "isLeader" true|false)

They differ only in `--api-server-count` and probes: in multi-node tensor
parallelism just rank 0 serves the API, so a worker has no HTTP listener and an
HTTP probe there would CrashLoop it. Both differences are static per template,
so the rank wiring needs no shell wrapper.
*/}}
{{- define "llm-d-model.modelPodSpec" -}}
{{- $ := .ctx -}}
{{- $isLeader := .isLeader -}}
{{- $ms := $.Values.modelServer -}}
{{- $cache := $ms.cache -}}
{{- $cachePVC := eq $cache.mode "pvc" -}}
{{- $src := $.Values.model.source -}}
{{- $fromPVC := ne ($src.claimName | default "") "" -}}
{{- $r := include "llm-d-model.resources" $ | fromYaml -}}
{{- $size := int $r.size -}}
{{- $gpuCount := int $r.gpuCount -}}
{{- $wantGPU := $r.wantGPU -}}
{{- $tpTotal := int $r.tensorParallelSize -}}
{{- /* A path into the mounted volume when serving from a PVC, else the HF repo id. */ -}}
{{- $modelArg := $.Values.model.name -}}
{{- if $fromPVC -}}
{{- $modelArg = printf "%s/%s" (trimSuffix "/" $src.mountPath) (trimPrefix "/" ($src.subPath | default "")) | trimSuffix "/" -}}
{{- end -}}
{{- $hasTP := false -}}
{{- range $ms.args -}}
{{- if hasPrefix "--tensor-parallel-size" (toString .) -}}{{- $hasTP = true -}}{{- end -}}
{{- end -}}
{{- if $r.runtimeClassName }}
runtimeClassName: {{ $r.runtimeClassName }}
{{- end }}
{{- with $r.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- if $ms.spread.enabled }}
{{- /* Selects every pod of this model, so one constraint spreads independent
replicas and sharded members alike. */}}
topologySpreadConstraints:
  - maxSkew: {{ $ms.spread.maxSkew }}
    topologyKey: {{ $ms.spread.topologyKey }}
    whenUnsatisfiable: {{ $ms.spread.whenUnsatisfiable }}
    labelSelector:
      matchLabels:
        {{- include "llm-d-model.selectorLabels" $ | nindent 8 }}
{{- end }}
{{- with $ms.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $ms.initContainers }}
initContainers:
  {{- toYaml . | nindent 2 }}
{{- end }}
containers:
  - name: vllm
    image: {{ $ms.image | quote }}
    imagePullPolicy: {{ $ms.imagePullPolicy }}
    {{- with $ms.command }}
    command:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    args:
      {{- if $ms.argsOverride }}
      {{- toYaml $ms.argsOverride | nindent 6 }}
      {{- else }}
      - {{ $modelArg | quote }}
      - {{ printf "--served-model-name=%s" $.Values.model.name | quote }}
      - {{ printf "--port=%d" (int $ms.port) | quote }}
      {{- if and $wantGPU (gt $tpTotal 1) (not $hasTP) }}
      - {{ printf "--tensor-parallel-size=%d" $tpTotal | quote }}
      {{- end }}
      {{- if gt $size 1 }}
      {{- /* LWS injects these into every container and the kubelet expands
      $(VAR) from the container's own env — no shell needed. */}}
      - {{ printf "--nnodes=%d" $size | quote }}
      - "--node-rank=$(LWS_WORKER_INDEX)"
      - "--master-addr=$(LWS_LEADER_ADDRESS)"
      - {{ printf "--api-server-count=%d" (ternary 1 0 $isLeader) | quote }}
      {{- end }}
      {{- range $ms.args }}
      - {{ toString . | quote }}
      {{- end }}
      {{- end }}
    env:
      {{- if $.Values.huggingfaceToken }}
      - name: HF_TOKEN
        valueFrom:
          secretKeyRef:
            name: {{ include "llm-d-model.authSecretName" $ }}
            key: HF_TOKEN
      {{- end }}
      - name: HF_HOME
        value: {{ $cache.mountPath | quote }}
      {{- with $ms.env }}
      {{- toYaml . | nindent 6 }}
      {{- end }}
    ports:
      - name: vllm
        containerPort: {{ $ms.port }}
        protocol: TCP
    volumeMounts:
      - name: shm
        mountPath: /dev/shm
      - name: model-cache
        mountPath: {{ $cache.mountPath }}
      {{- range $ms.scratchDirs }}
      - name: {{ .name }}
        mountPath: {{ .mountPath }}
      {{- end }}
      {{- if $fromPVC }}
      - name: model-source
        mountPath: {{ $src.mountPath }}
        readOnly: true
      {{- end }}
      {{- with $ms.extraVolumeMounts }}
      {{- toYaml . | nindent 6 }}
      {{- end }}
    {{- if $isLeader }}
    startupProbe:
      httpGet:
        path: /v1/models
        port: vllm
      {{- toYaml $ms.startupProbe | nindent 6 }}
    livenessProbe:
      httpGet:
        path: /health
        port: vllm
      {{- toYaml $ms.livenessProbe | nindent 6 }}
    readinessProbe:
      httpGet:
        path: /v1/models
        port: vllm
      {{- toYaml $ms.readinessProbe | nindent 6 }}
    {{- end }}
    resources:
      requests:
        cpu: {{ $r.cpu | quote }}
        memory: {{ $r.memory | quote }}
        {{- if $wantGPU }}
        {{ $r.gpuResourceName }}: {{ $gpuCount }}
        {{- end }}
      limits:
        memory: {{ $r.memory | quote }}
        {{- if $wantGPU }}
        {{ $r.gpuResourceName }}: {{ $gpuCount }}
        {{- end }}
volumes:
  - name: shm
    emptyDir:
      medium: Memory
      sizeLimit: {{ $ms.shm.sizeLimit }}
  - name: model-cache
    {{- if $cachePVC }}
    persistentVolumeClaim:
      claimName: {{ $.Release.Name }}-model-cache
    {{- else }}
    emptyDir:
      sizeLimit: {{ $r.storage | quote }}
    {{- end }}
  {{- range $ms.scratchDirs }}
  - name: {{ .name }}
    emptyDir: {}
  {{- end }}
  {{- if $fromPVC }}
  - name: model-source
    persistentVolumeClaim:
      claimName: {{ $src.claimName }}
      readOnly: true
  {{- end }}
  {{- with $ms.extraVolumes }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end -}}
