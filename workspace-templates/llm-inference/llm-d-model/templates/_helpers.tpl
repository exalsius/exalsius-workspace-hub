{{/*
Common labels.
*/}}
{{- define "llm-d-model.labels" -}}
app.kubernetes.io/name: llm-d-model
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{/* Release-scoped label on every model pod, so two models never cross-select. */}}
{{- define "llm-d-model.selectorLabels" -}}
app: {{ .Release.Name }}
{{- end -}}

{{/*
The *serving* pods — each LWS group's leader. Workers hold no API server, so a
Service selecting them would advertise endpoints that serve nothing. Equivalent
to selectorLabels at nodesPerReplica 1.
*/}}
{{- define "llm-d-model.leaderSelectorLabels" -}}
{{ include "llm-d-model.selectorLabels" . }}
leaderworkerset.sigs.k8s.io/worker-index: "0"
{{- end -}}

{{/*
Pod labels that make the InferencePool select this model. Source of truth is
igw.router.modelServers.matchLabels, since Helm cannot template subchart values.
LWS-managed keys are filtered out — stamping worker-index ourselves would brand
every worker as the leader.
*/}}
{{- define "llm-d-model.poolSelectorLabels" -}}
{{- $ms := (.Values.igw.router).modelServers | default dict -}}
{{- $labels := $ms.matchLabels | default dict -}}
{{- if not $labels -}}
{{- fail "igw.router.modelServers.matchLabels is required: it selects the model pods into the InferencePool" -}}
{{- end -}}
{{- $own := dict -}}
{{- range $k, $v := $labels -}}
{{- if not (hasPrefix "leaderworkerset.sigs.k8s.io/" $k) -}}
{{- $_ := set $own $k $v -}}
{{- end -}}
{{- end -}}
{{- if not $own -}}
{{- fail "igw.router.modelServers.matchLabels must contain at least one non-LWS label: LWS-managed labels alone cannot identify this model's pods" -}}
{{- end -}}
{{- range $k, $v := $own }}
{{ $k }}: {{ $v | quote }}
{{- end }}
{{- end -}}

{{/*
Resolves the injected `_exalsius` contract into the numbers the model server
needs, and validates the combination. Returned as YAML, read via fromYaml.

`replicas` stays "pods" and `gpuCount` stays "GPUs per pod", exactly as the
operator means them; nodesPerReplica divides that budget:

    size   = nodesPerReplica     pods serving ONE model
    groups = replicas / size     independent model replicas
    TP     = size * gpuCount     total shards
*/}}
{{- define "llm-d-model.resources" -}}
{{- $ex := .Values._exalsius | default dict -}}
{{- $res := $ex.resources | default dict -}}
{{- $per := $res.perReplica | default dict -}}
{{- $replicas := int ($res.replicas | default .Values.fallback.replicas) -}}
{{- /* Not `| default 1`: that treats an explicit (invalid) 0 as unset. */ -}}
{{- $sizeVal := .Values.modelServer.nodesPerReplica -}}
{{- $size := 1 -}}
{{- if not (kindIs "invalid" $sizeVal) -}}
{{- $size = int $sizeVal -}}
{{- end -}}
{{- if lt $size 1 -}}
{{- fail (printf "modelServer.nodesPerReplica must be at least 1, got %v" $sizeVal) -}}
{{- end -}}
{{- if lt $replicas $size -}}
{{- fail (printf "replicas (%d) is smaller than modelServer.nodesPerReplica (%d): one model replica needs %d pods, so at least that many must be requested" $replicas $size $size) -}}
{{- end -}}
{{- if ne (mod $replicas $size) 0 -}}
{{- fail (printf "replicas (%d) must be a whole multiple of modelServer.nodesPerReplica (%d) — each model replica occupies exactly %d pods, so a remainder would leave a partial, unservable group" $replicas $size $size) -}}
{{- end -}}
{{- $gpuResource := $per.gpuResourceName | default "" -}}
{{- $gpuCount := int ($per.gpuCount | default 0) -}}
{{- $wantGPU := and (ne $gpuResource "") (gt $gpuCount 0) -}}
{{- if and (gt $size 1) (not $wantGPU) -}}
{{- fail "modelServer.nodesPerReplica > 1 shards one model across pods with tensor parallelism, which requires GPUs: set _exalsius.resources.perReplica.gpuCount (and gpuResourceName)" -}}
{{- end -}}
{{- $runtimeClass := "" -}}
{{- if and $wantGPU (eq (lower (toString ($per.gpuVendor | default ""))) "nvidia") -}}
{{- $runtimeClass = .Values.gpu.nvidia.runtimeClassName -}}
{{- end -}}
{{- $cache := .Values.modelServer.cache -}}
{{- if and (eq $cache.mode "pvc") (eq $cache.accessMode "ReadWriteOnce") (gt $replicas 1) -}}
{{- fail (printf "modelServer.cache.mode=pvc with accessMode=ReadWriteOnce cannot serve %d pods: a ReadWriteOnce volume attaches to one node. Use accessMode ReadWriteMany, or mode emptyDir" $replicas) -}}
{{- end -}}
size: {{ $size }}
groups: {{ div $replicas $size }}
totalPods: {{ $replicas }}
tensorParallelSize: {{ mul $size $gpuCount }}
gpuCount: {{ $gpuCount }}
gpuResourceName: {{ $gpuResource | quote }}
wantGPU: {{ $wantGPU }}
runtimeClassName: {{ $runtimeClass | quote }}
cpu: {{ ($per.cpu | default .Values.fallback.cpu) | quote }}
memory: {{ ($per.memory | default .Values.fallback.memory) | quote }}
storage: {{ ($per.storage | default .Values.fallback.storage) | quote }}
nodeSelector:
{{- $sel := (($ex.scheduling | default dict).nodeSelector) | default dict }}
{{- if $sel }}
{{- toYaml $sel | nindent 2 }}
{{- else }} {}
{{- end }}
{{- end -}}

{{/* Named off the release so two models never share credentials. */}}
{{- define "llm-d-model.authSecretName" -}}
{{ .Release.Name }}-model-auth
{{- end -}}

{{/*
Matches the trusted X-Gateway-Model-Name header and forwards to this model's
InferencePool. External route only (docs/adr/0008).
*/}}
{{- define "llm-d-model.modelRouteRules" -}}
- timeouts:
    request: {{ .Values.httpRequestTimeout }}
  matches:
    - headers:
        - name: X-Gateway-Model-Name
          type: Exact
          value: {{ .Values.model.name }}
      path:
        type: PathPrefix
        value: /v1
  backendRefs:
    - group: inference.networking.k8s.io
      kind: InferencePool
      name: {{ .Release.Name }}
      weight: 1
{{- end -}}
