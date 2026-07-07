# llm-inference: shared inference gateway, infra as a prerequisite that also exposes Open WebUI

The `llm-inference` workspace ships as two umbrella charts mapped onto the
operator contract deliberately, because a shared inference stack does not fit the
plain one-chart-one-class shape — and because the operator's routing federates
endpoints from a Service **in the workspace's own namespace**.

**All models share one agentgateway gateway; each model backs its endpoint with
an in-namespace redirect Service.** `llm-d-infra` installs a **single** shared
[agentgateway](https://agentgateway.dev/) gateway (`llm-d-inference-gateway`) in
the `default` namespace — where prerequisites land — with two listeners:
`external` (:80) for model workspaces and `internal` (:8080) for Open WebUI. An
`llm-d-model` does **not** run its own gateway; it attaches `HTTPRoute`s to the
shared gateway and routes to its own `InferencePool`. To still satisfy the
operator's routing contract, the model creates a lightweight `<release>-http`
ClusterIP Service **in its own namespace** and a redirect `HTTPRoute` that
forwards to the shared gateway; the `http` `accessEndpoint` is backed by that
in-namespace Service (via the `<release>-<endpoint>` naming convention), so
operator routing works while the actual gateway is shared.

We earlier ran a **per-model gateway** (each model owns a gateway + Service in
its namespace) precisely because the operator's routing (`provider.go`) labels a
Service named `<release>-<endpoint>` **in the workspace's own namespace** as an
ambient global service and federates *its* endpoints — a Service in the `default`
namespace could never back a model's endpoint. We reversed that: one gateway per
model multiplies gateways, and Open WebUI (in the infra namespace) would need to
discover and reach each model's gateway individually. A single shared gateway
plus a thin in-namespace redirect Service satisfies the in-namespace requirement
*and* gives Open WebUI one stable entry point, one model-discovery surface, and
one BBR policy.

**Trusted model routing.** Routing keys on the `X-Gateway-Model-Name` header. For
external clients the model's redirect `HTTPRoute` **stamps** this header from the
chart's configured model name (so a client can't tamper with it to reach another
model); for Open WebUI the shared gateway's `internal` listener runs a
body-based-routing agentgateway policy that derives the header from the request
body. The per-model `external` and `internal` `HTTPRoute`s then match that header
and forward to the model's `InferencePool`.

**Optional external auth via an agentgateway policy.** `inferenceApiKey` attaches
a Strict `apiKeyAuthentication` `AgentgatewayPolicy` to the model's **external**
`HTTPRoute` only — gating the per-workspace public endpoint while leaving the
`internal` route open so cluster-internal consumers (Open WebUI, model discovery)
can list and call every model without a key. Keys live in a dedicated
`<release>-external-apikey` Secret, kept separate from the model-auth Secret
because agentgateway treats every entry in the referenced Secret as a valid key.

**llm-d-infra is an auto-installed, cluster-shared prerequisite — and also a
WorkspaceClass for Open WebUI.**
> **Superseded by [ADR-0006](0006-open-webui-routed-per-model-not-via-infra-class.md).**
> Infra no longer ships a WorkspaceClass — it is now a pure prerequisite, and Open
> WebUI is routed per-model via each `llm-d-model`'s `chat` endpoint. The
> double-install footgun described below no longer exists (there is no infra-as-class
> path to collide). The rest of this paragraph is kept for historical context.

The model's `WorkspaceClass.spec.prerequisites[]`
references the infra **ServiceTemplate** by exact name; the operator installs it
**once per ClusterDeployment** (into `default`) when absent and reuses it across
all models. Infra *also* ships a WorkspaceClass whose `accessEndpoint` routes
**Open WebUI** (operator routing needs a class with an in-namespace Service; a
bare prerequisite has none). Operational caveat: the prerequisite detector
recognizes colony- or wsprereq-installed infra, **not** a class-deployed infra
instance — so per cluster, either deploy infra-as-class *or* let models
auto-install it as a prerequisite; mixing both risks two infra copies.

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
</content>
</invoke>
