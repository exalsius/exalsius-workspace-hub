# Chart pre-release E2E runs through local-dev-env, against the operator built from `main`

Status: accepted (2026-07-02)

Before a workspace chart is published (immutably) to OCI, we deploy the *real* shipped
template — the chart plus its `exalsius/` CRs (ServiceTemplate + WorkspaceClass + example
WorkspaceDeployment) — through the full operator path on a live multi-cluster kind
environment and assert it reaches `Running` **and its routing actually carries traffic**
(live HTTP `curl` through the regional gateway LoadBalancer; SSH/TCP pool port reachable).
This complements the per-chart lint/template checks (`test-helm-charts.yaml`), which never
run the chart through the operator or exercise routing.

The environment and provisioning come from the sibling **local-dev-env** repo; the test
lives here. This mirrors the *shape* of exalsius-operator's pre-release gate
(operator ADR-0006) but deliberately **inverts what is under test** (see below).

## The shape

- **The environment lives in local-dev-env; the test lives here.** local-dev-env owns
  provisioning (`make up setup-kcm-regional-child` — management + regional + two adopted
  child kind clusters, Istio ambient, k0rdent, the regional `istio-ingressgateway`
  LoadBalancer via cloud-provider-kind, and the local kind registry). This repo's CI
  checks out local-dev-env with an App token and runs its shared CI scripts
  (`scripts/ci/render-components.sh`, `install-tools.sh`, `collect-diagnostics.sh`) plus
  the make targets.
- **Not a reusable workflow.** This repo is **public** and local-dev-env is **private**;
  GitHub forbids a public repo from calling a reusable workflow in a private one.
  `actions/checkout` of a private repo with a token has no such restriction, so
  checkout-and-run is the correct shape.
- **The test reuses the dev harness as its deploy engine.** `scripts/e2e/run.sh` computes
  the changed charts, derives each chart's needs from its own shipped CRs, drives the
  deploy through `scripts/dev/workspace-dev.sh` (`publish-prereq` → `up` → `down`), then
  asserts. The dev harness stays the single source of truth for the deploy path, so CI
  exercises the exact path a developer uses locally.
- **Only changed charts are tested.** `git diff origin/main...HEAD`, mapped to the nearest
  ancestor `Chart.yaml` directory, deduped. Because release-please is configured with
  `separate-pull-requests: true`, a release PR bumps exactly one chart — so the release
  gate is fast and targeted; the `e2e` label handles multi-chart feature PRs.
- **Per-chart specials are derived, not hardcoded.** Prerequisites come from the
  WorkspaceClass's `prerequisites[]` (resolved to sibling chart dirs and published as
  ServiceTemplates); GPU faking is driven by the example WSD's `gpuCount`/`gpuNodeSelector`;
  endpoints to probe come from the WorkspaceClass's `accessEndpoints`. An optional
  `workspace-templates/<chart>/e2e.yaml` override exists for irreducible specials, but the
  default is derivation so the test tracks exactly what ships.
- **Runner:** ephemeral self-hosted ARC pods with a privileged DinD sidecar (matches
  local-dev-env), so the kind clusters fit and tear down with the pod. A hard
  `timeout-minutes` guarantees a hung bring-up *fails* rather than hangs. An `always()`
  diagnostics step uploads pods/events/describe + operator/k0rdent logs + every
  WorkspaceDeployment status as a CI artifact, since the pod is gone after the run.
- **Gating:** the suite runs on release-please PRs (required, blocking) and opt-in via an
  `e2e` label on other PRs. An always-running sentinel `e2e-gate` job is the actual
  *required* status check, so non-release PRs (where the heavy job is skipped by design)
  are not blocked waiting on a status that never reports.

## The deliberate deviation: operator from `main`, not a pinned baseline

Operator ADR-0006 pins *every* component except the operator (which it builds from the PR)
so that "green means this operator works against the last known-good stack." **This gate
does the opposite for the operator**: the charts under test come from this PR, and the
operator is **built from `exalsius-operator` @ `main` from source** (checked out as a
sibling, `render-components.sh` `source.local` + `build.enabled`). The rest of the stack
(api, k0rdent, CAPI, Istio) stays pinned to local-dev-env's baseline.

We build the operator from source rather than pulling its moving `:dev` image because a
chart's CRs increasingly use newer WorkspaceClass fields (`resourceInjection`,
`prerequisites`); testing against `main` is only meaningful if the operator's **CRDs**
match its binary. Building from source keeps image, Helm chart, and CRDs coherent — pulling
only the image risks a CR field the `:dev` binary supports but the pinned chart's CRDs
reject.

### Consequences

- **A broken operator `main` can red a chart release PR.** This is accepted on purpose: it
  catches CR ↔ operator co-evolution before a chart is published immutably, which is the
  whole point of releasing a template against the operator it will run under. **Do not
  "restore" a pinned operator to this gate without revisiting this trade-off** — the
  coupling is deliberate, not an oversight. Cross-component drift beyond the operator is
  out of scope here.
- The gate depends on **three cross-repo checkouts** (this repo, local-dev-env, and
  exalsius-operator) and a GitHub App token scoped to the org (`contents:read` +
  `packages:read`). Environment changes (new cluster, bumped k0rdent) are made once in
  local-dev-env and require no change here.
- The suite proves selection/gating/injection/routing/scheduling **up to** real GPU
  *execution*, which kind cannot do (GPUs are faked — capacity patched, workload never
  touches the device), consistent with the dev harness and operator ADR-0002.
