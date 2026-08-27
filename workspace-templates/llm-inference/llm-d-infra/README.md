<p align="center"><img src="../../../docs/img/logo_banner.png" alt="exalsius banner" width="250"></p>

# llm-d-infra

Shared llm-d inference infrastructure for the exalsius operator. An umbrella
chart wrapping [agentgateway](https://agentgateway.dev/) and Open WebUI, plus
the `Gateway` this chart owns:

- **Shared inference gateway** — a single agentgateway `llm-d-inference-gateway`
  that every `llm-d-model` attaches to. Three listeners: `external` (:80), which
  model workspaces attach `HTTPRoute`s to, `internal` (:8080), used by Open WebUI
  and model discovery, and `webui` (:8081), which fronts Open WebUI itself.
  Rendered by `templates/gateway.yaml` — the upstream `llm-d-infra` chart that
  used to provide it was deprecated in llm-d 0.7.0 and its repository archived
  ([ADR-0007](../../../docs/adr/0007-llm-d-0.9-router-charts-and-owned-modelserver.md)).
- **Body-based routing (BBR)** — an agentgateway policy on the **internal**
  listener that extracts the model name from the request body into the
  `X-Gateway-Model-Name` header, so Open WebUI's model-agnostic requests route to
  the right model. (External clients don't rely on BBR — each model's chart stamps
  the trusted header on its own route.)
- **Model discovery** — exposes OpenAI-compatible `/v1/models` (on the internal
  listener) by aggregating `bbr-managed` ConfigMaps across namespaces, so Open
  WebUI can list every deployed model.
- **Open WebUI** — the chat interface, pointed at the gateway's internal listener.

## Role: a pure shared prerequisite

`llm-d-infra` is the **prerequisite** of [`llm-d-model`](../llm-d-model): the
operator auto-installs it **once per ClusterDeployment** (into the `default`
namespace) when the first model is deployed and reuses it across all models, via
its `ServiceTemplate` (`exalsius/servicetemplate.yaml`). Because the shared
gateway lives in `default`, each model attaches its routes there from its own
namespace (with a `ReferenceGrant`).

It ships **no `WorkspaceClass`** — a bare prerequisite can't own a routed
`AccessEndpoint`, so infra never routes anything itself. **Open WebUI** is exposed
**per model** instead: each `llm-d-model` carries a `chat` `AccessEndpoint` that
redirects to the gateway's `webui` listener (:8081), which forwards to the single
shared `llm-d-open-webui` Service here in `default` (via the gateway, because the
per-model redirect rides the ambient waypoint, which only reaches mesh-native
upstreams). This removes the old class-vs-prerequisite double-install footgun
structurally — there is no infra-as-class path to collide with the auto-installed
prerequisite
([ADR-0006](../../../docs/adr/0006-open-webui-routed-per-model-not-via-infra-class.md)).
Open WebUI is therefore reachable only once at least one model exists.

Services are **ClusterIP** — routing is operator-owned (the legacy NodePort and
`workspace.exalsius.ai/access-*` annotations were removed). The gateway's own
data-plane Service is pinned to ClusterIP by the `AgentgatewayParameters` that
`templates/gateway.yaml` renders; without it agentgateway would provision a
LoadBalancer. `appVersion` tracks the upstream llm-d release (`0.9.0`), kept
deliberately
([ADR-0002](../../../docs/adr/0002-llm-inference-prerequisite-and-umbrella-mapping.md)).

## Local render

```sh
helm dependency build ./llm-d-infra      # subcharts are vendored in charts/
helm template t ./llm-d-infra
```
