# Open WebUI is routed per-model, and llm-d-infra becomes a pure prerequisite

Status: accepted — supersedes the "infra ships both a ServiceTemplate and a
WorkspaceClass" decision and the double-install caveat in
[ADR-0002](0002-llm-inference-prerequisite-and-umbrella-mapping.md).

The shared Open WebUI is now routed **per `llm-d-model`** — each model's
WorkspaceClass exposes a second `chat` `accessEndpoint`, backed by an in-namespace
`<release>-chat` redirect Service that forwards to the shared gateway's `webui`
listener (`:8081`), which in turn forwards to the single shared Open WebUI
(`llm-d-open-webui`, in `default`) — and `llm-d-infra` drops its WorkspaceClass to
become a **pure prerequisite** (ServiceTemplate only).

**Why.** Routing is operator-owned and only a **WorkspaceClass** can own a routed
`AccessEndpoint`; a bare prerequisite cannot. Open WebUI lives inside `llm-d-infra`,
which is *primarily* the auto-installed prerequisite — a thing that can't route
itself. ADR-0002 worked around this by also shipping an infra **WorkspaceClass**
just to route Open WebUI, which introduced a footgun: the operator's prerequisite
detector does **not** recognize a class-deployed infra, so infra-as-class plus a
model auto-installing infra-as-prerequisite yields **two infra copies** (two
gateways, two Open WebUIs). The invariant "per cluster, pick one path, never mix"
had to live in an operator's head.

Hanging the route on the model's own class removes the footgun **structurally**:
there is no longer an infra-as-class path at all, so the collision cannot occur.
Open WebUI appears automatically the moment the first model deploys (the first
model brings up the infra prerequisite *and* mints the first `chat` door), reusing
the in-namespace-redirect-Service mesh pattern the `http` endpoint already uses
(ADR-0002) — no new workspace template, no bootstrap ritual.

**Why the `chat` redirect targets the gateway, not Open WebUI directly.** The
operator federates the `<release>-chat` Service and routes it through the ambient
**waypoint**, which forms healthy upstreams only to **mesh-native** destinations.
`http` works because its backend is the gateway itself (mesh-native); a first naive
`chat` implementation pointed straight at the `llm-d-open-webui` Service and got
`503 no healthy upstream` — a plain app Service in the non-ambient `default`
namespace is not a routable mesh upstream, even though the pod is healthy and
answers `200` on a direct in-cluster call. The fix mirrors `http`: redirect to the
gateway (a proven healthy upstream), and let the gateway — which *can* dial an
ordinary Service's endpoints — do the final hop. A dedicated `webui` listener
(`:8081`) carries this so Open WebUI traffic never touches the `external`/`internal`
listeners or BBR. Open WebUI is pinned to a fixed Service name (`llm-d-open-webui`,
mirroring the gateway's `llm-d-inference-gateway`) so the infra route can target it;
the release-relative `<release>-open-webui` only existed to satisfy the now deleted
infra class's naming convention.

**Considered — a standalone Open WebUI WorkspaceClass deployed once per cluster by
a platform admin** (infra pure prerequisite; admin bootstraps Open WebUI, which
lists infra as *its* prerequisite). Gives one canonical hostname and one login, and
also kills the footgun. Rejected because Open WebUI would then **not** appear on
first model deploy — it needs a deliberate admin step — and a model cannot surface
its own chat link. The automation and self-containment of per-model routing were
judged worth more than one canonical hostname.

**Consequences.**
- **N models → N hostnames onto one stateful Open WebUI.** Each `chat` endpoint is
  a real, distinct hostname (a browser origin), all served by the single Open WebUI
  backend. A user hopping between models' chat links **re-authenticates per host**
  (same account/DB, separate cookie per origin). Softenable later with a `?model=`
  pre-select param so each door opens focused on its own model.
- **No models → no chat door.** Open WebUI is reachable only while ≥1 model exists;
  deleting every model leaves Open WebUI running but unreachable until the next
  model. Correct for a UI whose only purpose is talking to models.
- **Open WebUI cannot be deployed standalone.** It only ever arrives as the
  auto-installed prerequisite — the infra WorkspaceClass and its example
  WorkspaceDeployment are deleted.
- **Single-tenant clusters only.** Every chat door shows the full cluster-wide
  model list (discovery is cluster-wide) and the gateway's internal listener is
  keyless, so any Open WebUI user can call any model. Sound when one
  ClusterDeployment is one trust boundary; a shared cluster would leak models
  across tenants. Scoping (namespace-filtered discovery, per-tenant Open WebUI, or
  auth on the internal listener) is out of scope and would be a follow-up.
