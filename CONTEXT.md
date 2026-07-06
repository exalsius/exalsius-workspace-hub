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
Shared inference infrastructure (a shared agentgateway, body-based routing, model
discovery, Open WebUI). A **pure prerequisite** — ships a ServiceTemplate **only**,
auto-installed once per ClusterDeployment as the cluster-shared prerequisite of
`llm-d-model`. It has **no WorkspaceClass**: infra never routes anything itself, so
the class-vs-prerequisite double-install footgun is structurally impossible. Open
WebUI runs under a fixed Service name (`llm-d-open-webui`) and is routed **per
model** via each `llm-d-model`'s `chat` endpoint (a prerequisite can't own a routed
endpoint, so the route must ride on a class that does — the model's).

**llm-d-model**:
A served model. Runs a GAIE InferencePool + llm-d-modelservice/vLLM in its own
namespace and attaches `HTTPRoute`s to the **shared** inference gateway (it does
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
`external` (:80) for model workspaces, `internal` (:8080) for Open WebUI's
model-discovery and model calls, and `webui` (:8081) fronting Open WebUI itself
(the target of each model's `chat` redirect). Each model still backs its endpoints
with in-namespace redirect Services so operator routing stays in-namespace.

**Body-based routing (BBR)**:
An agentgateway policy on the gateway's **internal** listener that extracts the
model name from the request body into the `X-Gateway-Model-Name` header, so Open
WebUI's model-agnostic requests match a model's `HTTPRoute`. External clients get
the header stamped by the model chart's redirect route instead. Models are
discovered via labeled ConfigMaps across namespaces.

**InferencePool**:
The GAIE pool of model-server pods a gateway route targets.

**modelservice**:
The llm-d subchart that runs vLLM decode/prefill pods. GPU count derives from
`parallelism.tensor`; vendor from `accelerator.type`.

**Model discovery / model-registry**:
The infra service exposing OpenAI-compatible `/v1/models` by aggregating model
names from `bbr-managed` ConfigMaps.
