<p align="center"><img src="../../../docs/img/logo_banner.png" alt="exalsius banner" width="250"></p>

# llm-d-infra

Shared llm-d inference infrastructure for the exalsius operator. An umbrella
chart wrapping the upstream `llm-d-infra` stack plus body-based routing and
Open WebUI:

- **Body-based routing (BBR)** — extracts the model name from the request body so
  gateways can route by model.
- **Model discovery** — exposes OpenAI-compatible `/v1/models` by aggregating
  `bbr-managed` ConfigMaps across namespaces (so Open WebUI can list every model).
- **Open WebUI** — the chat interface.

## Role: a shared prerequisite (that also exposes Open WebUI)

`llm-d-infra` is the **prerequisite** of [`llm-d-model`](../llm-d-model): the
operator auto-installs it **once per cluster** when the first model is deployed
and reuses it across all models, via its `ServiceTemplate`
(`exalsius/servicetemplate.yaml`).

It also ships a `WorkspaceClass` (`exalsius/workspaceclass.yaml`) so **Open WebUI**
gets an operator-routed endpoint — a bare prerequisite has no class and so can't
own a routed `AccessEndpoint`. Per cluster, deploy infra via the class **or** let
models auto-install it as a prerequisite, not both (avoids a double install).

Services are **ClusterIP** — routing is operator-owned (the legacy NodePort and
`workspace.exalsius.ai/access-*` annotations were removed). `appVersion` tracks
the upstream llm-d release (`0.6.0`), kept deliberately
([ADR-0002](../../../docs/adr/0002-llm-inference-prerequisite-and-umbrella-mapping.md)).

## ⚠ Flagged follow-up

With the per-model gateway design, how Open WebUI reaches each model's gateway —
and whether the shared `llm-d-inference-gateway` is still required — is unresolved
and must be validated against the operator dev harness (see ADR-0002).

## Local render

```sh
helm dependency build ./llm-d-infra      # subcharts are vendored in charts/
helm template t ./llm-d-infra
```
