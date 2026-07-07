# marimo — management-cluster manifests

These are the exalsius operator CRs that make this chart selectable as a
workspace, kept in lockstep with the chart and versioned together with it.

| File | Kind | Deployed to | Purpose |
|------|------|-------------|---------|
| `servicetemplate.yaml` | k0rdent `ServiceTemplate` | management cluster | Wraps one immutable chart version, sourced from the OCI HelmRepository. |
| `workspaceclass.yaml` | `WorkspaceClass` | management cluster | Version-named catalog entry users deploy from. |
| `example-workspacedeployment.yaml` | `WorkspaceDeployment` | (example) | Shows how to deploy, including picking a GPU node by raw label. |

## These are templates

Each file contains placeholders substituted from `../Chart.yaml` at release time:

- `${VERSION}` — the chart SemVer (e.g. `1.0.0`).
- `${VERSION_DASHED}` — `${VERSION}` with dots replaced by dashes for DNS-1123
  resource names (e.g. `1-0-0`), giving `marimo-1-0-0`.

On release, CI renders them into `manifests/marimo/${VERSION}/`, which is applied
to the management cluster (delivery mechanism handled separately). Rollback is a
`git revert` (and/or repointing a WorkspaceDeployment's `workspaceClassRef` at an
older version). The render/CI wiring is set up separately from the chart itself.

To render locally:

```sh
VERSION=$(yq .version ../Chart.yaml)
VERSION_DASHED=${VERSION//./-}
for f in servicetemplate workspaceclass example-workspacedeployment; do
  sed -e "s/\${VERSION_DASHED}/$VERSION_DASHED/g" -e "s/\${VERSION}/$VERSION/g" \
    "$f.yaml"
done
```
