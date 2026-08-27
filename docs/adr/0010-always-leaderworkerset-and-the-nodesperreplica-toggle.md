# The model server is always a LeaderWorkerSet; topology is one Helm value

Serving a model too large for one node means sharding it across pods with
tensor parallelism. This ADR records how that is expressed.

## Why the toggle is a Helm value and not a second WorkspaceClass

Topology cannot be expressed in the operator's resource contract.
`ResourceRequirements` is a **closed struct** — `cpu`, `memory`, `storage`,
`gpuCount`, `gpuVendor`, `gpuType`, `gpuNodeSelector` — with nowhere to put
"pods per model", and `resourceInjection` only routes those same seven fields.
So the discriminator has to live in Helm values regardless; the only real
question was whether to carry it on a second `WorkspaceClass`.

One class won. A second class would have bought per-topology `prerequisites`
(installing the LWS controller only for multi-node users), but that argument
evaporated once the chart became LWS-always: **every** model needs the
controller now, so it belongs to the shared prerequisite either way. What is
left is a single number, and splitting the catalog over one number costs more
in explanation than it saves.

## `nodesPerReplica` divides the budget, it does not add to it

The contract's own words: *"A workspace deploys Replicas pod-shaped instances,
each with PerReplica resources. Whether replicas are spread across Kubernetes
nodes or co-located is decided by the chart's affinity rules and the K8s
scheduler; this spec only describes total demand (Replicas × PerReplica)."*

That is permission to decide what a pod *means*. So:

```
size   = modelServer.nodesPerReplica    pods that together serve ONE model
groups = replicas / size                independent model replicas
TP     = size * gpuCount                total shards
```

`replicas` keeps meaning "pods" and `gpuCount` keeps meaning "GPUs per pod" —
exactly what the operator injects and exactly what it sums for feasibility.
Nothing about the operator's accounting changes; the chart just decides that
groups of `size` pods cooperate.

```
replicas=1, gpuCount=1, nodesPerReplica=1  ->  1 model,  TP=1       (1 pod)
replicas=2, gpuCount=1, nodesPerReplica=1  ->  2 models, TP=1 each  (2 pods)
replicas=2, gpuCount=1, nodesPerReplica=2  ->  1 model,  TP=2       (2 pods)
```

The last two ask the operator for identical resources. Whether those two pods
are two independent replicas behind the endpoint picker or one model split
across them is decided entirely by `nodesPerReplica` — which is the property
that made a single number the right shape for this.

The alternative — `replicas` meaning "model replicas" and a separate
`gpusPerNode` — would have made `replicas × perReplica` stop equalling total
demand, quietly breaking the feasibility gate. Rejected for that reason.

`replicas` must be a whole multiple of `nodesPerReplica`; the chart fails the
render otherwise rather than leave a partial group that could never serve.

## Always a LeaderWorkerSet, even at size 1

A `Deployment` would serve the single-node case, but then multi-node needs a
second workload kind and every selector, Service, probe and label forks with it.
LWS `size: 1` *is* the single-node case — per its own API docs, "when set to 1,
the leader pod is created for each group as well as a 0-replica StatefulSet for
the workers". One shape, and the only difference between the two topologies is a
number.

The cost is a controller dependency for every model, which is why the LWS chart
now ships inside the `llm-d-infra` umbrella (`oci://registry.k8s.io/lws/charts/lws`
v0.10.0). It brings its own CRDs and needs no cert-manager — `enableCertManager`
defaults false and the webhook certificate is self-signed.

## Leader and worker are separate templates

In multi-node tensor parallelism only rank 0 serves the OpenAI API; the other
ranks join over NCCL and serve nothing. Two consequences, both handled by
rendering `leaderTemplate` and `workerTemplate` separately (LWS renders only
`workerTemplate` at size 1, where it *is* the leader):

- **`--api-server-count`** is 1 on the leader, 0 on workers.
- **Probes are leader-only.** A worker has no HTTP server, so an HTTP liveness
  probe there fails forever and CrashLoops the pod. llm-d's own multi-node
  example puts HTTP probes on a single shared template and notes that workers
  "will show NotReady (expected)" — with a liveness probe that is not merely
  NotReady, it is a restart loop. Splitting the templates avoids it.

Because both differences are static per template, the rank wiring needs no shell
wrapper: `command` stays `["vllm","serve"]` and the kubelet expands
`--node-rank=$(LWS_WORKER_INDEX)` / `--master-addr=$(LWS_LEADER_ADDRESS)` from
the env LWS injects into every container.

## Routing must reach leaders only

The `InferencePool` selector and the two in-namespace redirect Services all
carry `leaderworkerset.sigs.k8s.io/worker-index: "0"`. Without it the pool would
route to workers that serve nothing.

LWS sets that label per pod, so the chart stamps every *other* key from
`igw.router.modelServers.matchLabels` onto the pod templates and filters out the
`leaderworkerset.sigs.k8s.io/` prefix — stamping `worker-index: "0"` ourselves
would brand every worker as the leader.

Note this is **`worker-index`, not `role`**. LWS `main` has a purpose-built
`leaderworkerset.sigs.k8s.io/role: leader` label, but it does not exist in
v0.10.0, the current release. `worker-index` is what v0.10.0 uses internally for
the same "select leaders" purpose.

## `restartPolicy` depends on the size

LWS defaults to `RecreateGroupOnPodRestart`, which deletes and recreates the
whole group when *any container* restarts. At `size: 1` that is strictly worse
than the Deployment it replaced: a transient vLLM crash costs the pod and with
it the emptyDir model cache, forcing a full re-download. Observed live while
debugging a startup failure — each crash produced a new pod, not a restart.

So the chart derives it: `None` at size 1 (a container restart is just that),
`RecreateGroupOnPodRestart` above 1 (the ranks are one NCCL job — if a shard
dies the others block on a peer that never returns, so they must come back
together). `modelServer.lwsRestartPolicy` overrides.

## Consequences

- **Single-node behaviour is unchanged in substance** but the workload kind is
  not: `kubectl get deploy` no longer shows the model. It is
  `kubectl get lws,pod`.
- **The feasibility gate cannot validate multi-node placement.** It sums
  allocatable across nodes ("approximate cluster-total") with no per-node fit,
  so a 2×4-GPU request passes on a cluster of 8 single-GPU nodes and then sits
  Pending. Documented, not fixable from the chart. Adding per-node fit to the
  gate is the natural home for a future first-class `nodesPerReplica`.
- **Spreading is a preference.** `modelServer.spread` renders a
  `ScheduleAnyway` topology-spread constraint over all of the model's pods, so
  it covers independent replicas and sharded members alike without ever
  blocking scheduling. Not a guarantee, and deliberately so — on the common
  shapes the GPU request already decides placement (two 1-GPU pods on two
  1-GPU nodes cannot co-locate). `DoNotSchedule` and `modelServer.affinity`
  are there for clusters that need it enforced.
- **Cross-node tensor parallelism wants a fast interconnect.** llm-d validates
  this shape on NVLink/RoCE. On plain Ethernet it will work and be slow.
- **All three layouts verified on real clusters** (H100, driver 580.105.08):
  - *single-node* (`size: 1`, 1 GPU): serves through both listeners; the
    LWS-always decision costs nothing in the common case.
  - *replicated* (2 groups × `size: 1`, 1 GPU each, two nodes): one pod per
    node, both in the pool, 24/24 and 40/40 requests served across both. Killing
    a replica mid-traffic lost **zero** requests.
  - *sharded* (1 group × `size: 2`, two nodes): `$(LWS_WORKER_INDEX)` expanded
    by the kubelet with no shell wrapper (rank 0 / rank 1, both pointed at the
    leader's headless DNS), cross-node NCCL came up
    (`world_size=2 ... backend=nccl` over `tcp://<leader>:29501`), and inference
    served with TP=2 spanning both nodes.
  - The leader/worker split was load-bearing, not defensive: the worker pod has
    **no HTTP listener at all** (verified: connection refused on :8000) while
    reporting `Ready`, because it has no probes. A shared template with HTTP
    probes would CrashLoop it — and under `RecreateGroupOnPodRestart` that would
    take the whole group down repeatedly.
  - `restartPolicy` confirmed on both sides: killing a *replica* at size 1 left
    the other untouched, while killing a *shard* recreated the entire group
    (both pods came back with the same new creation timestamp), which is the
    only correct behaviour when the leader is blocked on a missing NCCL peer.
