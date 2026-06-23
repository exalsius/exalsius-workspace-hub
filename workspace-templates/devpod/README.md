<p align="center"><img src="../../docs/img/logo_banner.png" alt="exalsius banner" width="250"></p>

# devpod

A single-user remote **development container** workspace for the exalsius
operator. Connect with Remote-SSH from VS Code, Cursor, or JetBrains and code
against cluster GPUs. **One framework-free image** runs on CPU, NVIDIA, and AMD
ROCm nodes — install PyTorch (cuda or rocm wheels) inside as needed. Resources,
GPU placement, the GPU resource name, and the GPU vendor are injected by the
operator via the `_exalsius` contract; SSH is exposed as a **ClusterIP** Service
and reached through operator-owned routing.

The management-cluster CRs that make this chart selectable as a workspace — its
`ServiceTemplate`, `WorkspaceClass`, and an example `WorkspaceDeployment` — live
in [`exalsius/`](./exalsius), versioned together with the chart.

The image is **selected by GPU vendor**
([ADR 0003](../../docs/adr/0003-gpu-workspace-images-are-vendor-selected.md)):
`image.default` (framework-free) serves CPU + NVIDIA, while `image.amd` is
ROCm-baked because AMD's userspace can't be injected at runtime. Each variant is
**pinned by digest**, decoupled from the chart version
([ADR 0001](../../docs/adr/0001-decouple-workspace-image-tag-from-chart-version.md)).
Real published digests must be set in `values.yaml` before release; until then
use the dev harness's `IMAGE_TAG=` override.

## Quickstart

### Using the exalsius CLI

```sh
exls workspace deploy devpod --ssh-password <your-secure-password>
```

### Using Helm (chart authoring / local testing)

```sh
helm install my-devpod ./devpod --set sshPassword=<password>
```

When installed directly with Helm, the `fallback.*` resources apply. When
deployed via the operator, `_exalsius.*` injection overrides them. See
`values-{nvidia,amd,cpu}.yaml` for examples that simulate the injection:

```sh
helm template t ./devpod -f ./devpod/values-nvidia.yaml
```

## SSH access

The `ssh` AccessEndpoint (port 22) is raw TCP, so the operator routes it via a
port-pool `TCPRoute`. Default user is `root`; authenticate with `sshPassword`
(required) and/or `sshPublicKey` (optional, one key per line). Add the
operator-provided host/port to your `~/.ssh/config` and use *Remote-SSH: Connect
to Host*.

## How GPUs work

- **NVIDIA**: the operator injects `gpuResourceName: nvidia.com/gpu`, a GPU
  count, and the GPU node selector; the chart applies `runtimeClassName`
  (`gpu.nvidia.runtimeClassName`, default `nvidia`) only for NVIDIA.
- **AMD ROCm**: the operator injects `gpuResourceName: amd.com/gpu`; no runtime
  class is set. The pod runs as root group (`fsGroup: 0`) so the ROCm devices
  attached by the AMD device plugin are usable.
- **CPU-only**: no GPU is requested, no node selector, no runtime class.

## Configuration

| Parameter | Description | Default |
| --- | --- | --- |
| `image.default.{repository,tag,digest}` | Framework-free image for CPU + NVIDIA (digest-pinned). | `ghcr.io/exalsius/devpod:latest` |
| `image.amd.{repository,tag,digest}` | ROCm-baked image, selected when `gpuVendor=AMD`. | `ghcr.io/exalsius/devpod:latest-rocm` |
| `image.pullPolicy` | Image pull policy. | `IfNotPresent` |
| `sshPassword` | SSH login password (set by the WorkspaceClass userFacingConfig). | `changeme` |
| `sshPublicKey` | Optional SSH public key(s), one per line. | `""` |
| `shmSizeGb` | Shared memory (`/dev/shm`) size in GiB. | `8` |
| `service.port` | ClusterIP Service port for the `ssh` endpoint (targetPort 22). | `22` |
| `gpu.nvidia.runtimeClassName` | RuntimeClass applied only for NVIDIA; `""` disables. | `nvidia` |
| `fallback.cpu` / `fallback.memory` / `fallback.storage` | Resources for a plain `helm install`; overridden by `_exalsius`. | `2` / `4Gi` / `50Gi` |
| `_exalsius` | Operator-injected resources/scheduling — **do not set by hand**. | `{}` |
