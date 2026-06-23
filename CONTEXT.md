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
Shared inference infrastructure (body-based routing, model discovery, Open
WebUI). Ships **both** a ServiceTemplate — the auto-installed, cluster-shared
prerequisite of `llm-d-model` — **and** a WorkspaceClass whose `accessEndpoint`
routes Open WebUI (a bare prerequisite has no class, so it can't own a routed
endpoint).

**llm-d-model**:
A served model. Runs its **own** GAIE gateway + InferencePool +
llm-d-modelservice/vLLM in its own namespace and exposes **one** `accessEndpoint`
— that model's OpenAI-compatible API, backed by its in-namespace gateway Service.
Its `WorkspaceClass` lists `llm-d-infra` as a prerequisite.

**Inference gateway**:
The istio Gateway fronting a model's InferencePool. One **per model workspace**
(in the model's own namespace) so the model's OpenAI endpoint is operator-routable
in-namespace.

**Body-based routing (BBR)**:
Extracts the model name from the request body into a header so the gateway's
`HTTPRoute` can match it. Discovers models via labeled ConfigMaps across
namespaces.

**InferencePool**:
The GAIE pool of model-server pods a gateway route targets.

**modelservice**:
The llm-d subchart that runs vLLM decode/prefill pods. GPU count derives from
`parallelism.tensor`; vendor from `accelerator.type`.

**Model discovery / model-registry**:
The infra service exposing OpenAI-compatible `/v1/models` by aggregating model
names from `bbr-managed` ConfigMaps.
