# llm-d-model — management-cluster manifests

The exalsius operator CRs that make this chart selectable as a workspace,
versioned together with the chart.

| File | Kind | Deployed to | Purpose |
|------|------|-------------|---------|
| `servicetemplate.yaml` | k0rdent `ServiceTemplate` | management cluster | Wraps one immutable chart version, sourced from the OCI HelmRepository. |
| `workspaceclass.yaml` | `WorkspaceClass` | management cluster | Version-named catalog entry; declares the `llm-d-infra` prerequisite and the `http` (OpenAI API) and `chat` (shared Open WebUI) endpoints. |
| `example-workspacedeployment.yaml` | `WorkspaceDeployment` | (example) | Deploys one model; the operator auto-installs the infra prerequisite. |

## Templates & placeholders

Substituted at release time by `scripts/render-workspace-manifests.sh`:

- `${VERSION}` / `${VERSION_DASHED}` — this chart's version.
- `${INFRA_VERSION}` / `${INFRA_VERSION_DASHED}` — the sibling `llm-d-infra`
  chart's version. The prerequisite pins the **exact** infra ServiceTemplate
  version, which this chart's own `${VERSION}` can't express; the render script
  resolves it from `../../llm-d-infra/Chart.yaml`.

## Notes

- **Prerequisite.** `spec.prerequisites[]` references `llm-d-infra` by exact
  ServiceTemplate name. The operator installs it once per ClusterDeployment and
  reuses its shared gateway across models.
- **Endpoint via a shared gateway.** The chart attaches `HTTPRoute`s to the
  shared `llm-d-inference-gateway` (in `default`) rather than running its own. The
  `http` AccessEndpoint is backed by an in-namespace `<release>-http` Service that
  redirects to the shared gateway, so operator routing stays in-namespace (see
  docs/adr/0002).
- **Chat via the shared Open WebUI.** The `chat` AccessEndpoint is backed by an
  in-namespace `<release>-chat` Service that redirects to the shared gateway's
  `webui` listener (:8081), which forwards to the single shared `llm-d-open-webui`
  Service in `default` — via the gateway, because the per-model redirect rides the
  ambient waypoint, which only reaches mesh-native upstreams. Open WebUI is routed
  per model because the infra prerequisite owns no WorkspaceClass (see
  docs/adr/0006); it is reachable only once ≥1 model exists.
- **No `resourceInjection`.** The chart owns the vLLM workload and reads the
  standard `_exalsius.resources` path directly — including `cpu`/`memory`, which
  the old modelservice umbrella could not accept. `gpuCount` becomes the per-pod
  accelerator request; `--tensor-parallel-size` is `gpuCount ×
  modelServer.nodesPerReplica` (see docs/adr/0007 and docs/adr/0010).
- **Label matching is no longer a sharp edge.** The InferencePool selector and
  the labels stamped on the vLLM pods both come from
  `igw.router.modelServers.matchLabels`, so there is one place to get right
  instead of two that had to agree. It only needs changing if two models share a
  namespace.
