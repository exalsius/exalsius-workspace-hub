<p align="center"><img src="../../../docs/img/logo_banner.png" alt="exalsius banner" width="250"></p>

# llm-d-model

Serves one LLM for inference with the [llm-d](https://llm-d.ai/) stack — the
[Gateway API Inference Extension](https://gateway-api-inference-extension.sigs.k8s.io/)
InferencePool plus [llm-d-modelservice](https://llm-d.ai/docs/architecture/Components/modelservice)
(vLLM). It attaches to the **shared** agentgateway installed by
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
  in `default`. Two more `HTTPRoute`s (bound to the gateway's `external` and
  `internal` listeners) match that header and route to this model's InferencePool.
  This keeps the endpoint's backing Service in-namespace — as operator routing
  requires — while the gateway itself is shared
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
- **Resources → subchart.** `resourceInjection` maps the resolved `_exalsius`
  fields: `gpuCount → ms.decode.parallelism.tensor` (vLLM tensor-parallelism;
  the subchart auto-derives the GPU request), `gpuVendor → ms.accelerator.type`,
  `replicas → ms.decode.replicas`.
- `appVersion` tracks the upstream llm-d release (`0.6.0`), kept deliberately.

## Quickstart

### Using the exalsius CLI

```sh
exls workspace deploy llm-d-model <CLI parameters>
```

### Using Helm (chart authoring / local testing)

```sh
helm dependency build ./llm-d-model      # subcharts are vendored in charts/
helm install my-llm-model ./llm-d-model \
  --set huggingfaceToken=<your-hf-token> \
  --set ms.modelArtifacts.uri="hf://Qwen/Qwen3-1.7B" \
  --set ms.modelArtifacts.name="Qwen/Qwen3-1.7B" \
  --set ms.modelArtifacts.labels."llm-d\.ai/model"="Qwen3-1.7B" \
  --set ip.inferencePool.modelServers.matchLabels."llm-d\.ai/model"="Qwen3-1.7B"
```

## Required configuration

The model label must match the inference-pool selector, or the gateway won't
route to the pool.

| Parameter | Description |
| --- | --- |
| `huggingfaceToken` | **Required.** HF token for pulling the model (stored in a Secret). |
| `ms.modelArtifacts.uri` | **Required.** HF model URI, e.g. `hf://Qwen/Qwen3-1.7B`. |
| `ms.modelArtifacts.name` | **Required.** Served model name, e.g. `Qwen/Qwen3-1.7B`. |
| `ms.modelArtifacts.labels."llm-d.ai/model"` | **Required.** Must equal the pool selector below. |
| `ip.inferencePool.modelServers.matchLabels."llm-d.ai/model"` | **Required.** Must equal the model label above. |
| `inferenceApiKey` | Optional bearer token for **external** access. Enforced by an agentgateway `apiKeyAuthentication` policy attached to this model's `external` `HTTPRoute` (not in vLLM); the `internal` route is left open for cluster-internal consumers. |
