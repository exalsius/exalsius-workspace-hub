# The model server runs llm-d's own vLLM build, not upstream vLLM

llm-d 0.8.0 moved its guides to upstream `docker.io/vllm/vllm-openai` and stopped
treating its own builds as the default. [ADR-0007](0007-llm-d-0.9-router-charts-and-owned-modelserver.md)
followed that and set `modelServer.image` to upstream vLLM v0.26.0. This ADR
reverses that choice: the default is `ghcr.io/llm-d/llm-d-cuda:v0.9.0`.

## Why

llm-d still publishes and uses its own images because upstream has real gaps.
From llm-d's own image-component README:

- **NVSHMEM on RoCE.** Upstream vLLM pins NVSHMEM to `v3.4.5`, which needs a
  patch guarding a case where "static_rate must be a known value and is passed
  directly to the device". llm-d's guidance is explicit: *"Any image running on
  RoCE should use `llm-d` image variants."*
- **KV-cache connectors.** The llm-d builds bundle the NIXL and
  `llmd-fs-connector` wheels that P/D disaggregation and tiered KV offload
  depend on. Upstream work (e.g. the EC connector) is still open.

llm-d's own multi-node `wide-ep-lws` guide pulls
`images/gpu-vllm/llm-d/release`, not the upstream component — the multi-node and
disaggregated paths are exactly where the gaps bite. Since this chart is meant to
grow into those paths, defaulting to the llm-d build avoids a later swap.

Upstream vLLM remains a one-line override, and the chart is written so it keeps
working (see below).

## What actually differs, and what the chart had to change

The two images are not drop-in equivalents. `docker/Dockerfile.cuda`:

| | upstream `vllm-openai` | `llm-d-cuda` |
| --- | --- | --- |
| user | root | **uid 2000**, group 0 |
| `HOME` | `/` | `/home/vllm` |
| cache paths | HOME-relative (`/.cache`, `/.triton`) | already redirected to `/tmp` (`TRITON_CACHE_DIR`, `NUMBA_CACHE_DIR`, `VLLM_CACHE_ROOT`, `OUTLINES_CACHE_DIR`) |
| `HF_HOME` | unset | `/var/lib/llm-d/.hf` (documented as over-writable) |
| `/models` | — | symlink to `$LLM_D_MODELS_DIR` |
| entrypoint | — | none; `command: ["vllm","serve"]` works on both |

Consequences for the chart:

- **`podSecurityContext.fsGroup: 0`** (new). The image runs non-root and reaches
  its writable paths through group 0 — it chowns them `root:0` and sets `g+rwX`,
  the OpenShift-compatible pattern. A dynamically provisioned PVC is otherwise
  `root:root 0755` and uid 2000 cannot write the weights into it. Only matters
  for `cache.mode: pvc`; an `emptyDir` is world-writable already. Harmless under
  the root-running upstream image.
- **`model.source.mountPath` moved from `/models` to `/model-source`.** `/models`
  is a symlink in this image; mounting over it would replace the image's own
  layout.
- **`scratchDirs` are now upstream-only.** `/.config`, `/.cache`, `/.triton`
  exist because upstream runs as root with `HOME=/`. llm-d-cuda needs none of
  them. They are kept populated by default so swapping `image` back to upstream
  works unchanged; on llm-d-cuda they are three empty volumes. Set to `[]` to
  drop them.
- **`HF_HOME` is still set explicitly** to the cache mount, overriding the
  image's `/var/lib/llm-d/.hf`. Intentional: the cache volume is what
  `_exalsius.resources.perReplica.storage` sizes.

## `TRITON_LIBCUDA_PATH` must be set on non-RHEL nodes

Found by deploying to an Ubuntu 24.04 H100 node: vLLM died before serving a
single request with `torch._inductor.exc.InductorError: CalledProcessError`.

At engine startup Triton JIT-builds a small CUDA shim, linking with
`gcc -l:libcuda.so.1 -L$TRITON_LIBCUDA_PATH`. llm-d-cuda is UBI-based and ships
the RHEL default `TRITON_LIBCUDA_PATH=/usr/lib64`, but on an Ubuntu node the
NVIDIA container runtime injects the driver into `/usr/lib/x86_64-linux-gnu`,
and gcc's own default search path inside a UBI image is `/usr/lib64` too — so
nothing resolves `libcuda.so.1` and the link fails. Confirmed in the container:
`/usr/lib64` had no libcuda; `ldconfig` resolved it to
`/usr/lib/x86_64-linux-gnu/libcuda.so.1`.

The chart therefore sets `TRITON_LIBCUDA_PATH=/usr/lib/x86_64-linux-gnu`.
llm-d's Dockerfile flags this as expected ("Can be overridden at runtime via
deployment config") and its own manifests set it explicitly for their
RHEL-based clusters — the value is a property of the *node*, not the image.

This is also what the retired chart's `LIBRARY_PATH` env was compensating for.
It was dropped as cruft during the ADR-0007 rewrite; it was load-bearing.

## Separately: `USER=llm-d` was missing

llm-d patches `USER=llm-d` into **every** image variant it ships — upstream vLLM
included — as a workaround for
[vllm-project/vllm#44548](https://github.com/vllm-project/vllm/issues/44548),
required on vLLM v0.20.0+ (torch 2.11) where a user lookup fails when the uid has
no passwd entry. ADR-0007 set the image to vLLM v0.26.0 without it, so this was
already a latent bug on the upstream default. It is now in `modelServer.env` and
applies to both images.

## Consequences

- **Pinned to the llm-d release cadence.** `modelServer.image` and `appVersion`
  now move together; a vLLM bump means waiting for an llm-d release, or an
  explicit override.
- **Larger image.** The llm-d build carries NVSHMEM, NIXL and the connector
  wheels. Relevant to first-pull latency on a cold node, not steady state.
- **AMD follows.** `values-amd.yaml` uses `ghcr.io/llm-d/llm-d-rocm:v0.9.0`, the
  ROCm sibling. A CPU-only path would use `ghcr.io/llm-d/llm-d-cpu:v0.9.0`,
  though `values-cpu.yaml` deliberately runs the inference *simulator* instead.
- **Verified on a cluster.** Deployed to a single-node Ubuntu 24.04 / H100
  (driver 580.105.08, CUDA 13.0) cluster: vLLM 0.26.0 serves, 0 restarts, and
  inference succeeds through both gateway listeners. Re-confirmed on a two-node
  cluster for the replicated and sharded layouts, including cross-node NCCL. The
  `fsGroup` interaction with a provisioned PVC is still unexercised — every run
  used the default `cache.mode: emptyDir`.
