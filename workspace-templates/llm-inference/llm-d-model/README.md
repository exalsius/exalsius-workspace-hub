<p align="center"><img src="../../../docs/img/logo_banner.png" alt="exalsius banner" width="250"></p>

# llm-d-model

Serves one LLM for inference with the [llm-d](https://llm-d.ai/) stack — the
[Gateway API Inference Extension](https://gateway-api-inference-extension.sigs.k8s.io/)
InferencePool plus [llm-d-modelservice](https://llm-d.ai/docs/architecture/Components/modelservice)
(vLLM). Each model workspace runs its **own** istio inference gateway and exposes
a **per-workspace OpenAI-compatible endpoint**.

## How it fits the operator contract

- **Prerequisite.** The `WorkspaceClass` declares [`llm-d-infra`](../llm-d-infra)
  as a prerequisite; the operator auto-installs it once per cluster and reuses it
  across all models.
- **Per-model endpoint.** The chart deploys its own `Gateway`
  (`llm-d-inference-gateway`, auto-provisioning Service
  `llm-d-inference-gateway-istio`) and `HTTPRoute` → InferencePool, all in the
  workspace's own namespace. The `llm-inference` `AccessEndpoint` is backed by
  that gateway Service (`serviceName`), so operator-owned routing works
  in-namespace ([ADR-0002](../../../docs/adr/0002-llm-inference-prerequisite-and-umbrella-mapping.md)).
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
| `inferenceApiKey` | Optional bearer token for **external** access. Enforced at the inference gateway's `external` listener (not in vLLM); the `internal` listener is not gated by it. |
