# llm-d-infra — management-cluster manifests

The exalsius operator CRs for the shared inference infrastructure, versioned
with the chart.

| File | Kind | Deployed to | Purpose |
|------|------|-------------|---------|
| `servicetemplate.yaml` | k0rdent `ServiceTemplate` | management cluster | Wraps one immutable chart version. Referenced as the `llm-d-model` prerequisite. |

## A pure prerequisite (no WorkspaceClass)

- **Prerequisite only.** `llm-d-model`'s WorkspaceClass references this
  `ServiceTemplate` by exact name; the operator auto-installs it once per
  ClusterDeployment and reuses it across models. Infra ships **no**
  `WorkspaceClass` — a bare prerequisite can't own a routed `AccessEndpoint`.
- **Open WebUI is routed per model.** Each `llm-d-model` carries a `chat`
  `AccessEndpoint` that redirects to the gateway's `webui` listener (:8081), which
  forwards to the single shared `llm-d-open-webui` Service here in `default` (via
  the gateway, because the per-model redirect rides the ambient waypoint, which
  only reaches mesh-native upstreams). This removes the old class-vs-prerequisite
  double-install footgun structurally — there is no infra-as-class path to collide
  with the auto-installed prerequisite. See
  [docs/adr/0006](../../../../docs/adr/0006-open-webui-routed-per-model-not-via-infra-class.md).

## Shared gateway

Infra installs the single shared agentgateway `llm-d-inference-gateway` (in
`default`, where prerequisites land) that every `llm-d-model` attaches to. Open
WebUI reaches it via the internal listener (:8080); models attach their
`HTTPRoute`s to the external listener (:80). See docs/adr/0002.

Templates substitute `${VERSION}` / `${VERSION_DASHED}` from `../Chart.yaml`.
