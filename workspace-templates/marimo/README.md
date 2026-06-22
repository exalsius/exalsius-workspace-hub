<p align="center"><img src="../../docs/img/logo_banner.png" alt="exalsius banner" width="250"></p>

# Marimo Workspace

A single-user [Marimo](https://marimo.io/) reactive-notebook workspace for the
exalsius operator. **One framework-free image** runs on CPU, NVIDIA, and AMD ROCm
nodes — install PyTorch (cuda or rocm wheels) inside the notebook as needed.
Resources, GPU placement, the GPU resource name, and the GPU vendor are injected
by the operator via the `_exalsius` contract; the service is exposed as
**ClusterIP** and reached through operator-owned routing.

The management-cluster CRs that make this chart selectable as a workspace — its
`ServiceTemplate`, `WorkspaceClass`, and an example `WorkspaceDeployment` — live
in [`exalsius/`](./exalsius), versioned together with the chart.

The container image is built in a separate repository and **pinned by digest**,
decoupled from this chart's version
([ADR 0001](../../docs/adr/0001-decouple-workspace-image-tag-from-chart-version.md)).
A real, published digest must be set in `values.yaml` (`image.digest`) before
release; until then use the dev harness's `IMAGE_TAG=` override.

## Quickstart

### Using the exalsius CLI

```sh
exls workspace deploy marimo --token-password <your-secure-password>
```

### Using Helm (chart authoring / local testing)

```sh
helm install my-marimo ./marimo --set tokenPassword=<password>
```

When installed directly with Helm, the `fallback.*` resources apply. When
deployed via the operator, `_exalsius.*` injection overrides them. See
`values-{nvidia,amd,cpu}.yaml` for examples that simulate the injection:

```sh
helm template t ./marimo -f ./marimo/values-nvidia.yaml
```

## How GPUs work

- **NVIDIA**: the operator injects `gpuResourceName: nvidia.com/gpu`, a GPU
  count, and the GPU node selector; the chart applies `runtimeClassName`
  (`gpu.nvidia.runtimeClassName`, default `nvidia`) only for NVIDIA.
- **AMD ROCm**: the operator injects `gpuResourceName: amd.com/gpu`; no runtime
  class is set. The notebook runs as root group (`fsGroup: 0`) so the ROCm
  devices attached by the AMD device plugin are usable.
- **CPU-only**: no GPU is requested, no node selector, no runtime class.

Pick a GPU node by label in the `WorkspaceDeployment` via
`resources.perReplica.gpuNodeSelector`, copying the selector straight from the
Colony GPU inventory (`Colony.status.gpuInventory[].offerings[].selector`).

## Configuration

| Parameter | Description | Default |
| --- | --- | --- |
| `image.repository` | Container image (framework-free base). | `ghcr.io/exalsius/marimo` |
| `image.tag` | Human-readable image label (immutability comes from `image.digest`). | `latest` |
| `image.digest` | Immutable image digest pin, decoupled from chart version. | _(set before release)_ |
| `image.pullPolicy` | Image pull policy. | `IfNotPresent` |
| `tokenPassword` | Password for the Marimo web UI (set by the WorkspaceClass userFacingConfig). | `changeme` |
| `service.port` | ClusterIP Service port for the `http` endpoint (targetPort is 8080). | `80` |
| `gpu.nvidia.runtimeClassName` | RuntimeClass applied only for NVIDIA; `""` disables. | `nvidia` |
| `fallback.cpu` / `fallback.memory` / `fallback.storage` | Resources used only for a plain `helm install`; overridden by `_exalsius` injection. | `2` / `4Gi` / `10Gi` |
| `_exalsius` | Operator-injected resources/scheduling — **do not set by hand**. | `{}` |
