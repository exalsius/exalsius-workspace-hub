<p align="center"><img src="../../../docs/img/logo_banner.png" alt="exalsius banner" width="250"></p>

# llm-d-model

Serves one LLM for inference with the [llm-d](https://llm-d.ai/) stack — the
[llm-d router](https://github.com/llm-d/llm-d) in gateway mode (a
[Gateway API Inference Extension](https://gateway-api-inference-extension.sigs.k8s.io/)
InferencePool plus its endpoint picker) in front of a vLLM `LeaderWorkerSet`
this chart owns. It attaches to the **shared** agentgateway installed by
[`llm-d-infra`](../llm-d-infra) and exposes two per-workspace endpoints: a
**per-workspace OpenAI-compatible API** (`http`) and a **front door to the shared
Open WebUI chat interface** (`chat`).

## How it fits the operator contract

- **Prerequisite.** The `WorkspaceClass` declares [`llm-d-infra`](../llm-d-infra)
  as a prerequisite; the operator auto-installs it once per cluster (into
  `default`) and reuses its shared gateway across all models.
- **Endpoint via a shared gateway.** The chart does **not** run its own gateway.
  In its own namespace it creates a `<release>-http` ClusterIP Service (which the
  `http` `AccessEndpoint` is backed by, via the `<release>-<endpoint>` naming
  convention) plus a redirect `HTTPRoute` that stamps the trusted
  `X-Gateway-Model-Name` header and forwards to the shared `llm-d-inference-gateway`
  in `default`. Two more `HTTPRoute`s, bound to the gateway's `external` and
  `internal` listeners, match that header and route to this model's InferencePool. This keeps the
  endpoint's backing Service in-namespace — as operator routing requires — while
  the gateway itself is shared
  ([ADR-0002](../../../docs/adr/0002-llm-inference-prerequisite-and-umbrella-mapping.md)).
- **Chat via the shared Open WebUI.** The `chat` `AccessEndpoint` is backed by a
  second in-namespace `<release>-chat` ClusterIP Service plus a redirect
  `HTTPRoute` that forwards (no header stamping) to the shared gateway's `webui`
  listener (:8081), which in turn forwards to the single shared `llm-d-open-webui`
  Service in `default`. It targets the gateway, not Open WebUI directly, because
  the per-model redirect rides the ambient waypoint, which only reaches mesh-native
  upstreams (the gateway) — a plain app Service yields "no healthy upstream". Open
  WebUI is routed **per model** — not by infra — because infra is a bare
  prerequisite that owns no WorkspaceClass and so cannot own a routed endpoint
  ([ADR-0006](../../../docs/adr/0006-open-webui-routed-per-model-not-via-infra-class.md)).
  The single Open WebUI is reachable only once ≥1 model exists.
- **Resources direct from `_exalsius`.** The chart owns the model server, so it
  reads the injected contract itself and needs no `resourceInjection`:
  `cpu`/`memory` become the container requests/limits, `gpuResourceName`+`gpuCount`
  the accelerator request, `storage` the model-cache volume size, and
  `scheduling.nodeSelector` the pod `nodeSelector`
  ([ADR-0007](../../../docs/adr/0007-llm-d-0.9-router-charts-and-owned-modelserver.md)).
- **Single-node and multi-node are one shape.** The model server is always a
  `LeaderWorkerSet`; `modelServer.nodesPerReplica` says how many pods serve one
  copy of the model. It divides the injected pod budget rather than adding to
  it — `replicas` stays "pods", `gpuCount` stays "GPUs per pod" — and the chart
  derives `groups = replicas / nodesPerReplica` and
  `--tensor-parallel-size = nodesPerReplica × gpuCount`
  ([ADR-0010](../../../docs/adr/0010-always-leaderworkerset-and-the-nodesperreplica-toggle.md)).
  Requires the LWS controller, which ships with the `llm-d-infra` prerequisite.
- `appVersion` tracks the upstream llm-d release (`0.9.0`), kept deliberately.

## Quickstart

### Using the exalsius CLI

```sh
exls workspace deploy llm-d-model <CLI parameters>
```

### Using Helm (chart authoring / local testing)

```sh
helm dependency build ./llm-d-model      # the router subchart is vendored in charts/
helm install my-llm-model ./llm-d-model \
  --set huggingfaceToken=<your-hf-token> \
  --set model.name="Qwen/Qwen3-1.7B"
```

## Layouts

`replicas` (pods) and `modelServer.nodesPerReplica` (pods per model) together
pick the layout. On a cluster of two 1-GPU nodes:

| | `replicas` | `gpuCount` | `nodesPerReplica` | Result |
| --- | --- | --- | --- | --- |
| Single-node | 1 | 1 | 1 | 1 pod, 1 model, TP=1 |
| Replicated | 2 | 1 | 1 | 2 pods, **2 independent models**, TP=1 each — the endpoint picker load-balances across both |
| Sharded | 2 | 1 | 2 | 2 pods, **1 model** split across them, TP=2 — only the leader serves |

Replicated and sharded ask the operator for exactly the same resources; the
difference is entirely whether those two pods are two models or one.

> **Replicated traffic is not split evenly, by design.** The endpoint picker's
> default profile weights `prefix-cache-scorer` at 3 against `queue-scorer` 2
> and `kv-cache-utilization-scorer` 2 — llm-d deliberately favours KV-cache
> reuse over even distribution, so a replica with a warm cache keeps winning.
> Measured on two H100 nodes: 3/21 for sequential requests, 14/26 for 40
> concurrent ones. Both replicas do carry load, and throughput scales; it just
> is not round-robin. For least-busy routing instead, set
> `igw.router.epp.pluginsConfigFile: payload-agnostic.yaml`, whose profile uses
> `active-request-scorer`.

## Required configuration

| Parameter | Description |
| --- | --- |
| `model.name` | **Required.** The Hugging Face model to serve, e.g. `Qwen/Qwen3-1.7B`. Doubles as the served model name the gateway routes on, so it must match what clients send in the OpenAI request body. |
| `huggingfaceToken` | HF token for pulling gated/private models (stored in a Secret). Not needed for public models. |
| `inferenceApiKey` | Optional bearer token for **external** access. Enforced by an agentgateway `apiKeyAuthentication` policy attached to this model's `external` `HTTPRoute` (not in vLLM); the `internal` route is left open for cluster-internal consumers. |
| `model.source.claimName` | Serve weights already on a PVC instead of pulling from Hugging Face. vLLM is pointed at `<mountPath>/<subPath>` while still advertising `model.name`. Replaces the old `ms.modelArtifacts.uri: pvc://…` form. |
| `modelServer.cache.mode` | `emptyDir` (default, per-pod, re-downloads on restart) or `pvc` (shared, survives restarts — needs `ReadWriteMany` above one replica). |
| `igw.router.modelServers.matchLabels` | The InferencePool's pod selector. The chart stamps these same labels onto the vLLM pods, so pool and pods are wired from **one** place. Only needs changing if two models share a namespace. |
| `modelServer.spread` | Preference for placing the model's pods on different nodes (`ScheduleAnyway` by default, so it never blocks scheduling). Applies to independent replicas and to the pods of one sharded replica alike. |
| `modelServer.nodesPerReplica` | Pods per model replica. `1` (default) = each pod is a whole model. Above 1 the model is sharded across that many nodes with tensor parallelism; `replicas` must be a whole multiple of it. See the caveats below. |

> **Node requirement.** vLLM CUDA images from llm-d 0.7.0 onward are built on
> CUDA 13.0.2 and require **NVIDIA driver 580 or newer**.

### Before using `nodesPerReplica > 1`

- **Feasibility is not checked per node.** The operator sums allocatable
  capacity cluster-wide, so a request for 2 pods × 4 GPUs passes the gate on a
  cluster of 8 single-GPU nodes and then sits `Pending`.
- **Tensor parallelism across nodes puts every forward pass on the network.**
  llm-d validates this shape on NVLink/RoCE fabrics. On plain Ethernet it works
  and is slow — if the model fits on one node, keep `nodesPerReplica: 1`.
- **Pod spreading is a preference, not a guarantee.**
  `modelServer.spread` adds a `ScheduleAnyway` topology-spread constraint, which
  the scheduler honours when it can and ignores when it cannot. In practice the
  GPU request usually decides it anyway — two 1-GPU pods on two 1-GPU nodes have
  nowhere else to go. Raise it to `DoNotSchedule` if you need it enforced.
