# Local chart-iteration harness

Iterate on a workspace chart **and its operator CRs** against the local-dev-env
kind clusters, through the real operator path (HelmRepository → ServiceTemplate →
WorkspaceClass → WorkspaceDeployment). For pure render checks without a cluster,
use `helm template` with the chart's `values-*.yaml` instead.

## Prerequisites

From the [`local-dev-env`](../../../local-dev-env) repo:

```sh
make up                       # kind mgmt cluster, k0rdent, operator, source-controller
make setup-kcm-regional-child # regional + 2 child clusters, Gateway API CRDs, tenant Gateway
```

The operator must be built from the branch you want to test (set
`components.exalsius-operator.source.local` in `local-dev-env/config/components.yaml`).

## Usage

```sh
make dev-up                         # package+push the chart, deploy ST/WSC/WSD (CPU)
make dev-redeploy                   # after editing the chart: re-push + recreate WSD
make dev-down                       # remove WSD/WSC/ServiceTemplate/HelmRepository
```

Watch it:

```sh
kubectl --context kind-exalsius -n kcm-system get wsd dev -w
kubectl --context kind-child-adopted-1 -n ws-dev get deploy,pod,svc,pvc
```

## How it works

```mermaid
flowchart TB
  edit([edit chart / exalsius/]) --> up[make dev-up]
  up -->|push| reg[(kind registry)]
  up -->|apply| hr[HelmRepository]
  up -->|render + apply| crs[ServiceTemplate + WorkspaceClass + WSD]
  subgraph mgmt["kind-exalsius (management)"]
    hr
    crs
    op[operator]
  end
  crs --> op
  hr -.-> reg
  op -->|deploy| child[workspace on child cluster]
  edit -. dev-redeploy .-> up
```

| Node / edge | What it is |
|---|---|
| **make dev-up** | packages + pushes the chart, applies the local HelmRepository, renders `exalsius/`, applies ServiceTemplate + WorkspaceClass + WorkspaceDeployment |
| **kind registry** | `localhost:5050` (push) / `kind-registry:5000` (in-cluster), plain-HTTP |
| **HelmRepository** | local `exalsius-workspace-hub` pointing at the kind registry — same name as prod, different URL |
| **operator** | pulls the chart and installs it into `ws-<name>` on the child cluster |
| **dev-redeploy** | fast loop: re-push + reconcile the HelmRepository + recreate the WSD |

It mirrors the production flow, but against the local kind registry instead of GHCR:

- Packages the chart and pushes it to the local kind registry
  (`oci://localhost:5050/charts`, plain-HTTP).
- Applies a `HelmRepository` named **`exalsius-workspace-hub`** pointing at the
  in-cluster registry — the same name the committed ServiceTemplates use, so they
  work unchanged locally and in prod (only the URL differs). No `flux` CLI needed.
- Renders the chart's `exalsius/` templates **on the fly** at the current
  `Chart.yaml` version (so ServiceTemplate/WorkspaceClass edits are tested too)
  and applies them.
- Builds the WorkspaceDeployment by patching the chart's
  `exalsius/example-workspacedeployment.yaml`: it reuses the example's
  chart-specific `spec.values` (e.g. `notebookPassword`) but sets the
  topology (cluster/namespace/class) and GPU/image from the flags.
- `dev-redeploy` re-pushes, pokes the `HelmRepository` to re-pull
  (`reconcile.fluxcd.io/requestedAt`), and recreates the WSD for a deterministic
  redeploy (the local registry tag is mutable, unlike prod OCI).

## Single chart

The harness is per-chart: `make dev-up CHART=<name>` works for any chart that
ships an `exalsius/` directory (ServiceTemplate + WorkspaceClass + example WSD).
Charts without it are rejected with a clear message. Today only
`jupyter-notebook` qualifies.

## GPU paths (NVIDIA / AMD)

kind has no real GPUs, and the operator's gate requires a node that matches the
selector **and** advertises allocatable `*/gpu`. The single example WSD covers
both CPU and GPU: the harness synthesizes the GPU selector from `VENDOR`, and
`dev-fake-gpu` uses the same label, so they match by construction.

```sh
make dev-fake-gpu VENDOR=nvidia     # label node + patch status allocatable nvidia.com/gpu=1
make dev-up GPU=1 VENDOR=nvidia IMAGE_REPO=srnbckr/devpod IMAGE_TAG=latest   # WSD selecting that node
```

Swap `VENDOR=amd` to exercise the ROCm branch (selector `amd.com/gpu.device-id=74a1`,
resource `amd.com/gpu`, no runtimeClass).

**Verify selection actually happened** — the operator should have matched the
selector, resolved the offering, and injected GPU placement into the chart:

```sh
# rendered pod on the child cluster:
kubectl --context kind-child-adopted-1 -n ws-dev get pod -o yaml | \
  yq '.items[0].spec | {nodeSelector, runtimeClassName, limits: .containers[0].resources.limits}'
# nvidia -> nodeSelector{nvidia.com/gpu.product: NVIDIA-L40}, runtimeClassName: nvidia, limits{nvidia.com/gpu: "1"}
# amd    -> nodeSelector{amd.com/gpu.device-id: 74a1},        no runtimeClassName, limits{amd.com/gpu: "1"}
```

**Negative test** — selection must *reject* an unavailable GPU. Run the same
deploy WITHOUT faking first; the WSD should go Failed:

```sh
make dev-up GPU=1 VENDOR=nvidia      # on an un-faked cluster
kubectl --context kind-exalsius -n kcm-system get wsd dev \
  -o jsonpath='{.status.phase} {.status.message}'   # -> Failed  No GPU matching ...
```

**Inventory** — after faking, the faked offering should appear in the Colony's
GPU inventory with the same selector you'd put in a real WSD:

```sh
kubectl --context kind-exalsius -n kcm-system get colony default \
  -o jsonpath='{.status.gpuInventory}' | jq
```

Cleanup:

```sh
make dev-down
make dev-unfake-gpu VENDOR=nvidia
```

This validates selection, gating, injection, and scheduling onto the GPU node —
everything except real GPU *execution*, which kind can't do.

## Variables

| Var | Default | Meaning |
|-----|---------|---------|
| `CHART` | `jupyter-notebook` | chart dir under `workspace-templates/` |
| `MGMT` | `kind-exalsius` | management cluster context |
| `CHILD_CTX` | `kind-child-adopted-1` | child cluster context (for GPU faking) |
| `CD` | `default-child-adopted-1` | target ClusterDeployment name |
| `NS` | `kcm-system` | namespace for ST/WSC/WSD |
| `WSD_NAME` | `dev` | WorkspaceDeployment name |
| `GPU` / `VENDOR` | `0` / `nvidia` | request a GPU; vendor for fake + selector |
| `IMAGE_REPO` / `IMAGE_TAG` | (chart default) | override the workspace image |

> GPU-workspace charts pin their image by digest and select it by vendor
> (`image.default` for NVIDIA/CPU, `image.amd` for AMD — ADR-0003). The
> override targets the variant the run will use (`image.amd` only when
> `GPU=1 VENDOR=amd`, else `image.default`), clears that variant's pinned digest,
> and forces `Always` pull. Pass `IMAGE_REPO`/`IMAGE_TAG` until a real digest is
> published, e.g. `IMAGE_REPO=srnbckr/devpod IMAGE_TAG=latest`.
