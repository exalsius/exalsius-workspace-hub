<p align="center"><img src="../../docs/img/logo_banner.png" alt="exalsius banner" width="250"></p>

# Jupyter Notebook Workspace

A single-user Jupyter Notebook workspace for the exalsius operator. The image is
**selected by GPU vendor** ([ADR 0003](../../docs/adr/0003-gpu-workspace-images-are-vendor-selected.md)):
a framework-free base for CPU + NVIDIA (install CUDA PyTorch via pip) and a
ROCm-baked image for AMD. Resources, GPU placement, the GPU resource name, and
the GPU vendor are injected by the operator via the `_exalsius` contract; the
service is exposed as **ClusterIP** and reached through operator-owned routing.

The management-cluster CRs that make this chart selectable as a workspace — its
`ServiceTemplate`, `WorkspaceClass`, and an example `WorkspaceDeployment` — live
in [`exalsius/`](./exalsius), versioned together with the chart.

## Quickstart

### Using the exalsius CLI

```sh
exls workspace deploy jupyter --notebook-password <your-secure-password>
```

### Using Helm (chart authoring / local testing)

```sh
helm install my-notebook ./jupyter-notebook --set notebookPassword=<password>
```

When installed directly with Helm, the `fallback.*` resources apply. When
deployed via the operator, `_exalsius.*` injection overrides them. See
`values-{nvidia,amd,cpu}.yaml` for examples that simulate the injection:

```sh
helm template t ./jupyter-notebook -f ./jupyter-notebook/values-nvidia.yaml
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
| `image.default.{repository,tag,digest}` | Framework-free image for CPU + NVIDIA (digest-pinned). | `ghcr.io/exalsius/jupyter-notebook:latest` |
| `image.amd.{repository,tag,digest}` | ROCm-baked image, selected when `gpuVendor=AMD` ([ADR 0003](../../docs/adr/0003-gpu-workspace-images-are-vendor-selected.md)). | `ghcr.io/exalsius/jupyter-notebook:latest-rocm` |
| `image.pullPolicy` | Image pull policy. | `IfNotPresent` |
| `notebookPassword` | Password for the Jupyter web UI (set by the WorkspaceClass userFacingConfig). | `changeme` |
| `service.port` | ClusterIP Service port for the `http` endpoint (targetPort is 8888). | `80` |
| `gpu.nvidia.runtimeClassName` | RuntimeClass applied only for NVIDIA; `""` disables. | `nvidia` |
| `fallback.cpu` / `fallback.memory` / `fallback.storage` | Resources used only for a plain `helm install`; overridden by `_exalsius` injection. | `2` / `4Gi` / `10Gi` |
| `_exalsius` | Operator-injected resources/scheduling — **do not set by hand**. | `{}` |
