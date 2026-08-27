# AgentgatewayModel replaces the model-registry service and the BBR policy

agentgateway **v1.4.1** adds the `AgentgatewayModel` API: a listener that admits
the kind serves agentgateway's built-in LLM paths, extracting the model name
from the request body and aggregating every attached model into an
OpenAI-compatible `/v1/models`.

That is precisely the pair of things `llm-d-infra` was hand-building. This ADR
records replacing them.

## What went away

| Deleted | Was doing |
| --- | --- |
| `files/model-discovery.py` (130 lines) + its Deployment, Service, SA, ClusterRole/Binding | Aggregating labelled ConfigMaps into `/v1/models` for Open WebUI |
| `templates/model-discovery-networking.yaml` | Routing `/v1/models` on the internal listener |
| `templates/agentgateway-bbr-policy.yaml` | Extracting `model` from the request body into `X-Gateway-Model-Name` |
| `llm-d-model/templates/configmap.yaml` | The `bbr-managed` ConfigMap each model published to be discovered |
| `llm-d-model`'s internal `HTTPRoute` | Matching that header on the internal listener |

Each `llm-d-model` now ships one `AgentgatewayModel` instead. Net: a Python
service, a cluster-wide ConfigMap-read RBAC grant, and a polling loop are gone
from the cluster.

## Decisions

**Version ahead of llm-d.** llm-d 0.9.0 pins agentgateway v1.1.0, which has no
`AgentgatewayModel`. v1.4.1 is the first release carrying it, and it builds
against `gateway-api-inference-extension v1.5.0` — the same GAIE the llm-d
router chart and our vendored CRDs use, so the pool contract is unchanged. The
feature is gated off by default upstream (`agentgatewayModels.enabled`) and is
still labelled **experimental**; we enable it explicitly.

**Keep the llm-d router in the path.** `provider: Custom` with
`custom.backendRef` pointing at the `InferencePool` — the CRD permits only a
namespace-local `Service` or `InferencePool`, and agentgateway resolves it
through the same backend resolver it uses for an `HTTPRoute` backendRef. The
endpoint picker still does prefix-cache- and load-aware selection. This is *not*
the "point agentgateway straight at an OpenAI provider" shape, which would have
bypassed llm-d entirely.

**Only the internal listener converts; the external one keeps its HTTPRoute.**
This is the load-bearing decision. The two listeners are not interchangeable:

- **internal** serves Open WebUI, a trusted client choosing among every model in
  the cluster. Taking the model name from the request body is exactly right.
- **external** is a *per-workspace public endpoint*. It must serve exactly the
  model that workspace deployed. The redirect route stamps the model name as a
  **trusted header** precisely so a client cannot reach a different model by
  changing the body — a model table keyed on client-controlled input cannot
  enforce that. Converting it would have been a silent authorization
  regression.

The optional API-key policy therefore stays attached to the external
`HTTPRoute`, unchanged. agentgateway supports both kinds on one gateway
(upstream's own `llm-and-httproute` translator fixture covers the mixed case);
here they are on separate listeners.

**`custom.formats` is required** and defaults to `Completions`, which resolves
to `/v1/chat/completions`. A custom provider with no per-format `path` override
falls back to `/v1` + the format's standard suffix, matching vLLM's own paths.
Embedding models add `Embeddings`.

## Consequences

- **`X-Gateway-Model-Name` is now external-only.** It is stamped by the redirect
  route and matched by the external route. Nothing sets or reads it on the
  internal path any more.
- **Discovery is no longer eventually-consistent.** The registry polled
  ConfigMaps every 30s; the model table is part of gateway config, so a model
  appears in `/v1/models` when its `AgentgatewayModel` is programmed.
- **Model names must be unique per cluster.** The model table is keyed on
  `match.model` across every model attached to the listener. Two workspaces
  serving the same Hugging Face model under the same name now collide on the
  internal listener, where before each had its own ConfigMap entry and the
  header match picked one arbitrarily. Matching is exact — no wildcards — so a
  workspace cannot shadow another's model by prefix.
- **The internal listener admits only `AgentgatewayModel`.** Adding an HTTPRoute
  there again requires re-adding `HTTPRoute` to that listener's
  `allowedRoutes.kinds`.
- **We are on an experimental API.** It is enabled by a feature gate upstream
  and may change shape before it stabilises. The blast radius is the internal
  (Open WebUI) path only — the external per-workspace API does not depend on it,
  so a regression degrades the chat UI rather than the served endpoints.
- **Untested end-to-end here.** The wiring is verified by schema validation
  against the vendored v1.4.1 CRDs and by reading agentgateway's own resolver
  code; `provider: Custom` + `InferencePool` has no upstream golden fixture. It
  needs a run on the dev harness before release.
