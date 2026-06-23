# GPU-workspace charts select the container image by GPU vendor

A GPU workspace chart (devpod, jupyter-notebook, marimo) models its image as a
vendor map — `image.default` for NVIDIA and CPU nodes, `image.amd` for AMD ROCm
nodes — and picks `image.amd` when the operator-injected
`_exalsius.resources.perReplica.gpuVendor` is `AMD`, otherwise `image.default`.
Each variant is pinned by its own digest ([ADR-0001](0001-decouple-workspace-image-tag-from-chart-version.md))
and a `WorkspaceDeployment` may override it.

**Why — a hard asymmetry between the vendors.** On NVIDIA, `runtimeClassName: nvidia`
(or the GPU Operator's default runtime) makes the container runtime **inject the
driver userspace** (libcuda, `nvidia-smi`) at runtime, and the CUDA toolkit/cuDNN
arrive via the user's pip wheels — so a single *framework-free* image genuinely
runs on CPU and NVIDIA. AMD has **no equivalent runtime injection**: the operator
injects only `gpuResourceName: amd.com/gpu` + the nodeSelector, and the AMD device
plugin merely attaches `/dev/kfd` and `/dev/dri`. The ROCm userspace (rocm-smi,
the HSA/ROCr runtime, hipcc, device libs) must be **present in the image** —
torch-rocm wheels cover only part of it. So one framework-free image cannot serve
AMD; AMD needs a ROCm-baked image.

This reverses the earlier "one framework-free image for CPU/NVIDIA/AMD" approach
in all three GPU-workspace charts, which silently failed to actually serve AMD.

**Known limitation (deferred).** Access to `/dev/kfd` / `/dev/dri` currently relies
on the container running as root plus `fsGroup: 0`. A non-root ROCm image would
need `supplementalGroups` for the `render`/`video` groups, whose GIDs are
**node-dependent** (vary by distro), so they aren't hardcoded here. Revisit if a
non-root image is adopted.
