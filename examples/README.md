# examples/ — runnable WorkspaceDeployment examples (not applied to the cluster)

**Generated — do not edit by hand.** Rendered from each chart's
`workspace-templates/<chart>/exalsius/example-workspacedeployment.yaml` alongside
the manifests (see `scripts/render-workspace-manifests.sh`).

```
examples/<chart>/<version>/example-workspacedeployment.yaml
```

These are illustrative WorkspaceDeployments an end user can adapt and `kubectl
apply`. They are intentionally outside `manifests/`, so the cluster delivery
does **not** apply them — only ServiceTemplates and WorkspaceClasses are
reconciled onto the cluster.
