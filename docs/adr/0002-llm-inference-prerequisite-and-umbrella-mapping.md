# llm-inference: per-model serving endpoint, infra as a shared prerequisite that also exposes Open WebUI

The `llm-inference` workspace ships as two umbrella charts mapped onto the
operator contract deliberately, because a shared inference stack does not fit the
plain one-chart-one-class shape — and because the operator's routing federates
endpoints from a Service **in the workspace's own namespace**.

**Each llm-d-model exposes its own per-workspace OpenAI endpoint.** A model runs
its **own** GAIE gateway + InferencePool + modelservice in its **own** namespace
and exposes a single `accessEndpoint` (the OpenAI-compatible API) backed by that
in-namespace gateway Service. We rejected the alternative — all models behind one
shared infra gateway, with the model declaring an endpoint that points at the
shared gateway — because the operator's routing (`provider.go`) labels a Service
named `serviceName` **in the workspace's own namespace** as an Istio ambient
global service and federates *its* endpoints; the shared gateway lives in a
different namespace (`default`, where prerequisites install), so a model could
never back its endpoint with it. Per-model gateways put the backing Service
in-namespace, which is exactly what the mechanism requires.

**llm-d-infra is an auto-installed, cluster-shared prerequisite — and also a
WorkspaceClass for Open WebUI.** The model's `WorkspaceClass.spec.prerequisites[]`
references the infra **ServiceTemplate** by exact name; the operator installs it
**once per ClusterDeployment** when absent and reuses it across all models. Infra
*also* ships a WorkspaceClass whose `accessEndpoint` routes **Open WebUI**
(operator routing needs a class with an in-namespace Service; a bare prerequisite
has none). Operational caveat: the prerequisite detector recognizes colony- or
wsprereq-installed infra, **not** a class-deployed infra instance — so per
cluster, either deploy infra-as-class *or* let models auto-install it as a
prerequisite; mixing both risks two infra copies.

**GPU maps to vLLM parallelism, not an explicit limit.** Via `resourceInjection`,
`gpuCount → ms.decode.parallelism.tensor` and `gpuVendor → ms.accelerator.type`;
the modelservice subchart auto-derives the GPU resource request and the vLLM
`--tensor-parallel-size`. One coherent knob for single-node tensor parallelism.
Known gap: the operator injects `nodeSelector` only at the fixed
`_exalsius.scheduling.nodeSelector` path (not via `resourceInjection`), so GPU-node
*model* targeting (`gpuType`) cannot yet be bridged into `ms.decode.nodeSelector`
— the GPU resource request alone still pins pods to GPU nodes. Revisit if/when the
operator supports scheduling injection into mapped paths.

**appVersion is kept (scoped exception to ADR-0001).** These umbrella charts wrap
**upstream** llm-d images, and `appVersion` meaningfully documents which llm-d
release (`0.6.0`) the chart pins — unlike a digest-pinned exalsius-built image. So
`appVersion` stays as the upstream-version tracker for the `llm-inference` charts.
