# Inference-stack CRDs (GAIE + agentgateway) ship in the llm-d-infra chart's `crds/`

The cluster-scoped CRDs the llm-inference stack depends on are vendored into
[`llm-d-infra/crds/`](../../workspace-templates/llm-inference/llm-d-infra/crds)
rather than installed as cluster infrastructure:

- **`gaie.crds-v1.4.0.yaml`** — Gateway API Inference Extension: `InferencePool`
  (`inference.networking.k8s.io/v1`) plus the `inference.networking.x-k8s.io`
  objectives the endpoint-picker watches, pinned to the GAIE **v1.4.0** release.
- **`agentgateway.crds-v1.0.0.yaml`** — the agentgateway CRDs the routing layer
  uses, pinned to **v1.0.0**.

The chart carries the CRDs; the cluster is not expected to pre-install them.

The GAIE bundle arrived with the llm-d 0.6.0 alignment (#82); the agentgateway
bundle with the agentgateway routing refactor (dropping external body-based
routing). This ADR records the rationale and trade-offs of that placement — the
same reasoning covers both bundles.

**Why — the CRDs are the missing piece, and the chart is the only place we
control.** The upstream subcharts ship the *instances* (an `InferencePool`, the
endpoint-picker, the agentgateway resources) but not the CRDs; GAIE and
agentgateway, like the Gateway API itself, expect the CRDs installed separately.
The data plane is otherwise ready on the target clusters — only the CRDs are
absent. Shipping them in the chart makes an `llm-inference` workspace
self-sufficient on any cluster (dev kind clusters and bare production clusters
alike) without a separate platform step.

**Why llm-d-infra, not llm-d-model.** A CRD is cluster-scoped infrastructure.
`llm-d-infra` is the once-per-`ClusterDeployment` prerequisite that *is* the
cluster's shared inference infrastructure ([ADR-0002](0002-llm-inference-prerequisite-and-umbrella-mapping.md)),
so the operator installs it before any model deploys — the CRDs are established
before `llm-d-model`'s `InferencePool` instance is ever applied. `llm-d-model`
carries no `crds/` and relies on the prerequisite.

**Considered — cluster-level install in local-dev-env.** Installing the upstream
release manifests onto the clusters (beside the existing Gateway API
`experimental-install`) was the obvious mirror of how Gateway API CRDs are
handled, and matches a real platform admin installing them once. Rejected for
this round because it couples the workspace template to a specific environment's
provisioning and leaves the chart non-portable; the chart-vendored route keeps
the gap closed inside this repo. The decision is reversible: a platform that
later owns CRD installation loses nothing, because Helm only creates `crds/`
when absent (see consequences).

**Consequences.**
- **Non-destructive on a cluster that already has them.** Helm installs `crds/`
  only when the CRD is absent and never replaces it, so a production cluster that
  already manages GAIE/agentgateway is untouched — no collision, no version fight.
- **Helm never *upgrades* `crds/`.** A cluster that installed an older CRD keeps
  it; bumping a vendored version does not propagate on chart upgrade. The
  prerequisite is pinned by exact version, so the CRD versions track the pinned
  infra; a true CRD upgrade is a manual cluster operation.
- **Depends on the installer honoring `crds/` — confirmed.** The operator installs
  charts via k0rdent ServiceTemplate → Sveltos. If Sveltos did not apply a chart's
  `crds/`, this approach would silently fail and we would fall back to a
  cluster-level install. Verified on the local dev harness: installing
  llm-d-infra established all five GAIE CRDs on the child cluster
  (`inferencepools.inference.networking.k8s.io` et al., `bundle-version: v1.4.0`),
  so Sveltos does apply `crds/`.
