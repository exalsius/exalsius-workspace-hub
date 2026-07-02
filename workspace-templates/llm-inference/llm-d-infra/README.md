<p align="center"><img src="../../../docs/img/logo_banner.png" alt="exalsius banner" width="250"></p>

# llm-d-infra

Shared llm-d inference infrastructure for the exalsius operator. An umbrella
chart wrapping [agentgateway](https://agentgateway.dev/), the upstream
`llm-d-infra` stack, and Open WebUI:

- **Shared inference gateway** — a single agentgateway `llm-d-inference-gateway`
  that every `llm-d-model` attaches to. It has two listeners: `external` (:80),
  which model workspaces attach `HTTPRoute`s to, and `internal` (:8080), used by
  Open WebUI and model discovery.
- **Body-based routing (BBR)** — an agentgateway policy on the **internal**
  listener that extracts the model name from the request body into the
  `X-Gateway-Model-Name` header, so Open WebUI's model-agnostic requests route to
  the right model. (External clients don't rely on BBR — each model's chart stamps
  the trusted header on its own route.)
- **Model discovery** — exposes OpenAI-compatible `/v1/models` (on the internal
  listener) by aggregating `bbr-managed` ConfigMaps across namespaces, so Open
  WebUI can list every deployed model.
- **Open WebUI** — the chat interface, pointed at the gateway's internal listener.

## Role: a shared prerequisite (that also exposes Open WebUI)

`llm-d-infra` is the **prerequisite** of [`llm-d-model`](../llm-d-model): the
operator auto-installs it **once per ClusterDeployment** (into the `default`
namespace) when the first model is deployed and reuses it across all models, via
its `ServiceTemplate` (`exalsius/servicetemplate.yaml`). Because the shared
gateway lives in `default`, each model attaches its routes there from its own
namespace (with a `ReferenceGrant`).

It also ships a `WorkspaceClass` (`exalsius/workspaceclass.yaml`) so **Open WebUI**
gets an operator-routed endpoint — a bare prerequisite has no class and so can't
own a routed `AccessEndpoint`. Per cluster, deploy infra via the class **or** let
models auto-install it as a prerequisite, not both (avoids a double install).

Services are **ClusterIP** — routing is operator-owned (the legacy NodePort and
`workspace.exalsius.ai/access-*` annotations were removed). `appVersion` tracks
the upstream llm-d release (`0.6.0`), kept deliberately
([ADR-0002](../../../docs/adr/0002-llm-inference-prerequisite-and-umbrella-mapping.md)).

## Local render

```sh
helm dependency build ./llm-d-infra      # subcharts are vendored in charts/
helm template t ./llm-d-infra
```
