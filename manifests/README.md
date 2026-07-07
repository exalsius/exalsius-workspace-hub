# manifests/ — rendered, version-pinned workspace operator CRs

**Generated — do not edit by hand.** Files here are rendered from each chart's
`workspace-templates/<chart>/exalsius/` templates by
`scripts/render-workspace-manifests.sh`, run automatically when a new chart
version is published (see `.github/workflows/build-helm-charts.yaml`). Edit the
`exalsius/` templates, not these.

Layout:

```
manifests/<chart>/<version>/
  servicetemplate.yaml   # k0rdent ServiceTemplate, wraps the OCI chart version
  workspaceclass.yaml    # WorkspaceClass catalog entry (version-named)
```

This tree is applied to the management cluster (delivery mechanism handled
separately), so:

- Each released version is an immutable `ServiceTemplate` + `WorkspaceClass` pair;
  multiple versions coexist.
- **Rollback** = point a `WorkspaceDeployment` at an older version (the old CRs
  are still here), or `git revert` a release.
- **Retiring** a version = delete its `manifests/<chart>/<version>/` directory.

Runnable examples (not applied to the cluster) live under `examples/<chart>/<version>/`.
