# llm-d-model — management-cluster manifests

The exalsius operator CRs that make this chart selectable as a workspace,
versioned together with the chart.

| File | Kind | Deployed to | Purpose |
|------|------|-------------|---------|
| `servicetemplate.yaml` | k0rdent `ServiceTemplate` | management cluster | Wraps one immutable chart version, sourced from the OCI HelmRepository. |
| `workspaceclass.yaml` | `WorkspaceClass` | management cluster | Version-named catalog entry; declares the `llm-d-infra` prerequisite, the per-model OpenAI endpoint, and the resource→subchart injection. |
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
  reuses it across models.
- **Per-model endpoint.** Each model runs its own istio Gateway
  (`llm-d-inference-gateway`, auto-provisioning Service
  `llm-d-inference-gateway-istio`), referenced by the `llm-inference`
  AccessEndpoint's `serviceName`.
- **Label matching (sharp edge).** `ms.modelArtifacts.labels."llm-d.ai/model"`
  must equal `ip.inferencePool.modelServers.matchLabels."llm-d.ai/model"`, or the
  gateway won't route to the pool. The example sets both.
