# exalsius workspace templates

Versioned units that make a workload type deployable through the exalsius
operator: a Helm **chart** (runs on child clusters) plus the management-cluster
CRs that make it selectable. This glossary fixes the vocabulary; the authoring
guide is [`docs/adding-a-workspace-template.md`](docs/adding-a-workspace-template.md).

## Language

### The contract

**Workspace template**:
The shippable unit — one chart plus its `exalsius/` CRs (`ServiceTemplate` +
`WorkspaceClass`, and an example `WorkspaceDeployment`), versioned and released
together.

**ServiceTemplate**:
Management-cluster CR (k0rdent) wrapping exactly one immutable chart version,
sourced from the OCI `HelmRepository`. The unit a prerequisite references.

**WorkspaceClass**:
Version-named catalog entry a user deploys from. Owns `defaultResources`,
`accessEndpoints`, `userFacingConfig`, `prerequisites`, and `resourceInjection`.

**WorkspaceDeployment**:
End-user intent to run a workspace; pins one `WorkspaceClass` by
`workspaceClassRef`.

**_exalsius contract**:
The operator-injected `_exalsius.*` values block (resources, GPU, scheduling)
that a chart consumes, with chart-local `fallback.*` for plain `helm install`.

**Prerequisite**:
A `ServiceTemplate` that must be healthy on the target cluster before a
dependent workspace deploys. Declared in `WorkspaceClass.spec.prerequisites[]`
by exact ServiceTemplate name. The operator auto-installs it **once per
ClusterDeployment** as a shared `ServiceSet`; many dependents converge on the
single install. It is a ServiceTemplate, **not** a WorkspaceClass — a
prerequisite is never user-deployed directly.
_Avoid_: dependency, requirement.

**AccessEndpoint**:
A network endpoint a `WorkspaceClass` exposes (HTTP/TCP/SSH). The routing
provider backs it with a Service named `<release>-<endpoint>` by convention;
`serviceName` overrides that for fixed third-party umbrella-subchart Service
names. Routing is operator-owned — charts expose **ClusterIP** only.

**resourceInjection**:
A `WorkspaceClass` map directing resolved `_exalsius` resource fields
(cpu/memory/storage/gpuCount/gpuVendor/gpuType/replicas) to additional Helm
value paths — used to reach subchart paths in umbrella charts. The standard
`_exalsius.resources` path is always populated; this adds chart-specific ones.
Scheduling (`nodeSelector`) is **not** injectable this way — it lands only at
the fixed `_exalsius.scheduling.nodeSelector`.

**Port pool**:
How the operator routes a raw-TCP (SSH/TCP) `AccessEndpoint`: it allocates a
port from the regional gateway's pool and attaches a `TCPRoute` (no hostname,
since raw TCP carries none). HTTP endpoints get hostname routing instead.
Requires the Gateway API experimental channel on the regional cluster.

### Workspaces

**devpod**:
A single-user remote development container reached over SSH (Remote-SSH from
VS Code, Cursor, or JetBrains). One framework-free image; GPU optional.
_Avoid_: vscode-devcontainer (the former name), dev-pod, devcontainer.

### llm inference

**llm-d-infra**:
Shared inference infrastructure (a shared agentgateway and Open WebUI; model
routing and discovery are the gateway's own, via **AgentgatewayModel**). Our
chart, not the upstream one of the same name — that
was deprecated in llm-d 0.7.0 and archived, and the `Gateway` it used to render
is now ours ([ADR-0007](docs/adr/0007-llm-d-0.9-router-charts-and-owned-modelserver.md)).
A **pure prerequisite** — ships a ServiceTemplate **only**,
auto-installed once per ClusterDeployment as the cluster-shared prerequisite of
`llm-d-model`. It has **no WorkspaceClass**: infra never routes anything itself, so
the class-vs-prerequisite double-install footgun is structurally impossible. Open
WebUI runs under a fixed Service name (`llm-d-open-webui`) and is routed **per
model** via each `llm-d-model`'s `chat` endpoint (a prerequisite can't own a routed
endpoint, so the route must ride on a class that does — the model's).

**llm-d-model**:
A served model. Runs a GAIE InferencePool + endpoint picker (from the llm-d
router chart) in front of a chart-owned vLLM LeaderWorkerSet, in its own
namespace, and attaches `HTTPRoute`s to the **shared** inference gateway (it does
not run its own). Exposes **two** `accessEndpoint`s, each backed by an in-namespace
redirect Service (`<release>-<endpoint>`): `http` — the model's
OpenAI-compatible API, redirecting to the shared gateway — and `chat` — the shared
Open WebUI, redirecting to `llm-d-open-webui` in `default`. Its `WorkspaceClass`
lists `llm-d-infra` as a prerequisite.

**Chat endpoint**:
The `chat` `AccessEndpoint` on every `llm-d-model`, backed by an in-namespace
`<release>-chat` Service that redirects to the shared gateway's **`webui`
listener** (`:8081`), which in turn forwards to the single shared Open WebUI
(`llm-d-open-webui`, in `default`). It redirects to the gateway rather than to Open
WebUI directly because the operator's per-model redirect rides the ambient
waypoint, which forms healthy upstreams only to mesh-native destinations (the
gateway) — a plain app Service in the non-ambient `default` namespace yields "no
healthy upstream". It gives each model its own operator-routed front door to the
**one** shared chat UI — the route hangs off the model's class because the infra
prerequisite has none. Consequences of the shared instance: Open
WebUI is reachable only once ≥1 model exists (the first model brings up both infra
and the first door); every door serves the full cluster-wide model list (discovery
is cluster-wide); and each door is a distinct browser origin, so users
re-authenticate per model host. Sound on a **single-tenant cluster** (one
ClusterDeployment = one trust boundary); a shared cluster would leak models across
tenants via the keyless internal listener.

**Inference gateway**:
The single shared agentgateway (`llm-d-inference-gateway`, in `default`) installed
by `llm-d-infra`. Every model attaches to it via `HTTPRoute`s. Three listeners:
`external` (:80) for model workspaces, which attach `HTTPRoute`s; `internal`
(:8080) for Open WebUI's discovery and model calls, which admits
`AgentgatewayModel` **instead of** `HTTPRoute` and so serves `/v1/models` and
body-matched routing itself; and `webui` (:8081) fronting Open WebUI (the target
of each model's `chat` redirect). Each model still backs its endpoints with
in-namespace redirect Services so operator routing stays in-namespace.

**AgentgatewayModel**:
One per `llm-d-model`, attached to the gateway's **internal** listener and
pointing at that model's `InferencePool` via `provider: Custom` +
`custom.backendRef`. Because the listener admits the kind, agentgateway extracts
the model name from the request body and serves `/v1/models` itself — replacing
both the old body-based-routing policy and the `model-registry` service
([ADR-0008](docs/adr/0008-agentgateway-model-api-replaces-model-registry.md)).
Requires agentgateway ≥ v1.4.1 with `agentgatewayModels.enabled`; still
experimental upstream.
_Avoid_: BBR, model-registry, model discovery (all retired).

**X-Gateway-Model-Name**:
The **external**-only trusted header. Stamped by a model's `<release>-http`
redirect route and matched by its `external` `HTTPRoute`. It exists so a
per-workspace public endpoint serves exactly the model that workspace deployed —
which is why the external listener was *not* converted to `AgentgatewayModel`,
whose matching reads client-controlled request bodies.

**InferencePool**:
The GAIE pool of model-server pods a gateway route targets. Rendered by the
llm-d router chart, named off the Helm release.

**llm-d router**:
The upstream chart (`llm-d-router-gateway`) that replaced the GAIE `inferencepool`
chart in llm-d 0.9.0. Renders the `InferencePool`, the endpoint picker (EPP,
formerly `llm-d-inference-scheduler`) and its RBAC. Aliased `igw` in
`llm-d-model`. Its sibling `llm-d-router-standalone` — EPP plus a sidecar proxy,
no Gateway — is the mode we do *not* use.

**Model server**:
The vLLM `LeaderWorkerSet` in `llm-d-model/templates/modelserver.yaml`. Owned by
the chart, because upstream's replacement for the deprecated
`llm-d-modelservice` chart is a Kustomize base. It reads `_exalsius` directly,
which is why `llm-d-model` has no `resourceInjection`. Always an LWS, never a
Deployment — `size: 1` is the single-node case
([ADR-0010](docs/adr/0010-always-leaderworkerset-and-the-nodesperreplica-toggle.md)).
_Avoid_: modelservice (the retired subchart), "the model Deployment".

**nodesPerReplica**:
`modelServer.nodesPerReplica` — how many pods together serve ONE copy of the
model. 1 (default) = single-node. Above 1 the model is sharded across that many
nodes with tensor parallelism. It *divides* the operator's pod budget rather
than adding to it: `replicas` stays "pods", `gpuCount` stays "GPUs per pod", and
the chart derives `groups = replicas / nodesPerReplica` and
`TP = nodesPerReplica * gpuCount`. `replicas` must be a whole multiple of it.

**Leader / worker**:
The pods of one LWS group. Only the leader runs the OpenAI API server
(`--api-server-count 1`); workers join over NCCL and serve nothing, so they get
no probes and are excluded from every selector via
`leaderworkerset.sigs.k8s.io/worker-index: "0"`. At `nodesPerReplica: 1` the
leader is the only pod.

**Model table**:
The set of `AgentgatewayModel`s attached to the gateway's internal listener.
agentgateway aggregates it into OpenAI-compatible `/v1/models` and matches
request bodies against it. Keyed on `match.model`, so served model names must be
unique per cluster.
