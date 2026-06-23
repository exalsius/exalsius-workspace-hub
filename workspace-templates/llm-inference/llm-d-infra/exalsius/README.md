# llm-d-infra — management-cluster manifests

The exalsius operator CRs for the shared inference infrastructure, versioned
with the chart.

| File | Kind | Deployed to | Purpose |
|------|------|-------------|---------|
| `servicetemplate.yaml` | k0rdent `ServiceTemplate` | management cluster | Wraps one immutable chart version. Referenced as the `llm-d-model` prerequisite **and** backs the WorkspaceClass below. |
| `workspaceclass.yaml` | `WorkspaceClass` | management cluster | Routes the shared Open WebUI endpoint. |
| `example-workspacedeployment.yaml` | `WorkspaceDeployment` | (example) | Deploy the shared infra explicitly (usually unnecessary — auto-installed as a prerequisite). |

## Two roles, one ServiceTemplate

- **Prerequisite.** `llm-d-model`'s WorkspaceClass references this
  `ServiceTemplate` by exact name; the operator auto-installs it once per
  ClusterDeployment and reuses it across models.
- **Standalone class.** The `WorkspaceClass` exists so Open WebUI gets an
  operator-routed `AccessEndpoint` (a bare prerequisite has no class, so it
  can't own a routed endpoint).

> Operational caveat: the prerequisite detector recognizes colony- or
> wsprereq-installed infra, **not** a class-deployed instance. Per cluster,
> choose one path — deploy infra as a class *or* let models auto-install it —
> to avoid two infra copies.

## Flagged follow-up

With the per-model gateway design (docs/adr/0002), how Open WebUI reaches each
model's gateway — and whether the shared `llm-d-inference-gateway` is still
needed — is unresolved and must be validated against the operator dev harness.
Templates substitute `${VERSION}` / `${VERSION_DASHED}` from `../Chart.yaml`.
