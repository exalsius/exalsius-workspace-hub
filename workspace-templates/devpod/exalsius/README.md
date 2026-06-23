# devpod — management-cluster manifests

These are the exalsius operator CRs that make this chart selectable as a
workspace, kept in lockstep with the chart and versioned together with it.

| File | Kind | Deployed to | Purpose |
|------|------|-------------|---------|
| `servicetemplate.yaml` | k0rdent `ServiceTemplate` | management cluster | Wraps one immutable chart version, sourced from the OCI HelmRepository. |
| `workspaceclass.yaml` | `WorkspaceClass` | management cluster | Version-named catalog entry users deploy from. |
| `example-workspacedeployment.yaml` | `WorkspaceDeployment` | (example) | Shows how to deploy, including picking a GPU node by raw label. |

## These are templates

Each file contains placeholders substituted from `../Chart.yaml` at release time:

- `${VERSION}` — the chart SemVer (e.g. `0.2.0`).
- `${VERSION_DASHED}` — `${VERSION}` with dots replaced by dashes for DNS-1123
  resource names (e.g. `0-2-0`), giving `devpod-0-2-0`.

On release, CI renders them into `manifests/devpod/${VERSION}/`, applied to the
management cluster. Rollback is a `git revert` (and/or repointing a
WorkspaceDeployment's `workspaceClassRef` at an older version).

## SSH endpoint

The `ssh` AccessEndpoint is `protocol: SSH` on port 22. SSH is raw TCP, so the
operator allocates a port from the regional gateway's **port pool** and attaches
a `TCPRoute` (no hostname); the backend is the chart's `<release>-ssh` Service.
This requires the Gateway API experimental channel (TCPRoute) on the regional
cluster.
