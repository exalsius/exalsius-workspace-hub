#!/usr/bin/env bash
#
# Chart pre-release E2E (ADR-0005).
#
# For every CHANGED chart, deploy the REAL shipped template — chart + its
# exalsius/ CRs (ServiceTemplate + WorkspaceClass + example WorkspaceDeployment)
# — through the full operator path on a live local-dev-env kind environment, and
# assert it reaches Running AND its routing actually carries traffic (live HTTP
# curl through the regional gateway LoadBalancer; SSH/TCP pool port reachable).
#
# It reuses scripts/dev/workspace-dev.sh as the deploy engine (publish-prereq ->
# up -> down), so CI exercises the exact path a developer uses locally. The only
# new logic here is: change detection, per-chart derivation of needs, and the
# assertions.
#
# Per-chart needs are DERIVED from the chart's own shipped CRs:
#   * prerequisites  <- WorkspaceClass.spec.prerequisites[].serviceTemplate.name
#                       (mapped back to a sibling chart dir by chart .name)
#   * GPU required   <- WorkspaceClass.spec.defaultResources.perReplica.gpuCount > 0
#   * endpoints      <- WorkspaceClass.spec.accessEndpoints[] (HTTP -> curl,
#                       SSH/TCP -> socket)
# An optional workspace-templates/<chart>/e2e.yaml override may set:
#   skip: true | gpu: true|false | vendor: nvidia|amd | prerequisites: [<dir>...]
#
# Runs ALL changed charts (teardown between each), records pass/fail per chart,
# prints a summary, and exits non-zero if anything failed.
#
# Assumes local-dev-env `make up` + `make setup-kcm-regional-child` have run
# (mgmt + regional + two child kind clusters, Istio ambient, the regional
# ingress Gateway LoadBalancer via cloud-provider-kind, and the kind registry).
#
# Config via env (defaults match scripts/dev/workspace-dev.sh / local-dev-env):
#   BASE_REF (origin/main)  MGMT (kind-exalsius)  REG_CTX (kind-regional-adopted)
#   CHILD_CTX (kind-child-adopted-1)  CD (default-child-adopted-1)  NS (kcm-system)
#   WSD_NAME (e2e)  GW_NS (istio-system)  GW_SVC (istio-ingressgateway-istio)
#   CHARTS (override: space-separated chart ids under workspace-templates/,
#           bypassing git-diff detection)
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}" || exit 1
DEV="${REPO_ROOT}/scripts/dev/workspace-dev.sh"

BASE_REF="${BASE_REF:-origin/main}"
MGMT="${MGMT:-kind-exalsius}"
REG_CTX="${REG_CTX:-kind-regional-adopted}"
CHILD_CTX="${CHILD_CTX:-kind-child-adopted-1}"
CD="${CD:-default-child-adopted-1}"
NS="${NS:-kcm-system}"
WSD_NAME="${WSD_NAME:-e2e}"
GW_NS="${GW_NS:-istio-system}"
GW_SVC="${GW_SVC:-istio-ingressgateway-istio}"

# Timeouts (seconds).
RUN_TIMEOUT="${RUN_TIMEOUT:-600}"  # reach Running / backend answers (image pulls are slow)
SETTLE="${SETTLE:-180}"            # status / route objects settle
SHORT="${SHORT:-60}"               # quick socket checks

# Minimal coloured output.
print_status()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
print_success() { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
print_warning() { printf '\033[1;33m!\033[0m %s\n' "$*"; }
print_error()   { printf '\033[1;31m✗\033[0m %s\n' "$*"; }

PASS=0
FAIL=0
declare -a FAILED=()
LB_IP=""

# check <timeout> <desc> <snippet> — poll the snippet (eval'd, so it sees the
# globals above) until it exits 0 or the timeout elapses.
check() {
  local timeout="$1" desc="$2" snippet="$3"
  local end=$(( SECONDS + timeout )) out rc
  while :; do
    out="$(eval "$snippet" 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ]; then
      print_success "PASS  ${desc}"; PASS=$(( PASS + 1 )); return 0
    fi
    [ "$SECONDS" -ge "$end" ] && break
    sleep 4
  done
  print_error "FAIL  ${desc}"
  [ -n "${out:-}" ] && printf '        %s\n' "$(printf '%s' "$out" | head -n2 | tr '\n' ' ')"
  FAILED+=("${desc}"); FAIL=$(( FAIL + 1 )); return 1
}

# ---- Chart-name -> dir map (for resolving prerequisite ServiceTemplate names)

declare -A CHART_NAME_TO_DIR=()
build_chart_index() {
  local cf d n
  while IFS= read -r cf; do
    [ -n "$cf" ] || continue
    d="${cf%/Chart.yaml}"; d="${d#workspace-templates/}"
    n="$(yq '.name' "$cf")"
    CHART_NAME_TO_DIR["$n"]="$d"
  done < <(find workspace-templates -name Chart.yaml -type f | sort)
}

# resolve_prereq_dir <serviceTemplateName> — the prereq ST name is
# "<chartName>-<versionish>" (with a ${...} placeholder in the raw template);
# match it back to the sibling chart dir by longest chart-name prefix.
resolve_prereq_dir() {
  local st="$1" n best="" bestlen=0
  for n in "${!CHART_NAME_TO_DIR[@]}"; do
    if [ "$st" = "$n" ] || [ "${st#"$n"-}" != "$st" ]; then
      if [ "${#n}" -gt "$bestlen" ]; then best="${CHART_NAME_TO_DIR[$n]}"; bestlen="${#n}"; fi
    fi
  done
  printf '%s' "$best"
}

# ---- Changed-chart detection: git diff -> nearest Chart.yaml dir -> dedup

changed_charts() {
  if [ -n "${CHARTS:-}" ]; then printf '%s\n' $CHARTS; return 0; fi
  local files f dir
  files="$(git diff --name-only "${BASE_REF}...HEAD" 2>/dev/null)" \
    || files="$(git diff --name-only HEAD~1 HEAD 2>/dev/null)" || files=""
  {
    while IFS= read -r f; do
      case "$f" in workspace-templates/*) ;; *) continue ;; esac
      dir="$(dirname "$f")"
      # Walk up to the nearest ancestor that has a Chart.yaml.
      while [ "$dir" != "." ] && [ "$dir" != "workspace-templates" ]; do
        if [ -f "$dir/Chart.yaml" ]; then echo "${dir#workspace-templates/}"; break; fi
        dir="$(dirname "$dir")"
      done
    done <<< "$files"
  } | sort -u
}

# ---- Gateway LoadBalancer IP (regional ingress)

discover_lb() {
  LB_IP="$(kubectl --context "$REG_CTX" -n "$GW_NS" get svc "$GW_SVC" \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)"
  [ -n "$LB_IP" ]
}

preflight() {
  print_status "Preflight"
  local ok=1 c
  for c in "$MGMT" "$REG_CTX" "$CHILD_CTX"; do
    kubectl config get-contexts -o name | grep -qx "$c" \
      || { print_error "kube-context '$c' missing — run local-dev-env make up + setup-kcm-regional-child"; ok=0; }
  done
  command -v jq   >/dev/null 2>&1 || { print_error "jq not found on PATH"; ok=0; }
  command -v curl >/dev/null 2>&1 || { print_error "curl not found on PATH"; ok=0; }
  command -v yq   >/dev/null 2>&1 || { print_error "yq not found on PATH"; ok=0; }
  command -v helm >/dev/null 2>&1 || { print_error "helm not found on PATH"; ok=0; }
  discover_lb || { print_error "gateway Service ${GW_SVC} (${GW_NS}) has no LoadBalancer IP"; ok=0; }
  [ "$ok" -eq 1 ] || { print_error "Preflight failed."; exit 1; }
  print_success "Preflight OK (gateway LB ${LB_IP})"
}

# ---- Per-chart derivation (CRs, with optional e2e.yaml override)

# Populated by derive_chart.
D_SKIP=""; D_GPU=""; D_VENDOR=""; declare -a D_PREREQS=(); declare -a D_HTTP=(); declare -a D_TCP=()
derive_chart() {
  local chart="$1" cdir="workspace-templates/${1}" class ov
  class="${cdir}/exalsius/workspaceclass.yaml"
  ov="${cdir}/e2e.yaml"
  D_SKIP="false"; D_GPU=""; D_VENDOR="nvidia"; D_PREREQS=(); D_HTTP=(); D_TCP=()

  [ -f "$class" ] || { D_SKIP="true"; return; }

  # GPU: class defaultResources mandates a GPU when gpuCount > 0.
  local gc; gc="$(yq '.spec.defaultResources.perReplica.gpuCount // 0' "$class")"
  [ "${gc:-0}" -gt 0 ] 2>/dev/null && D_GPU="1" || D_GPU="0"

  # Prerequisites: resolve each referenced ServiceTemplate name to a chart dir.
  local st dir
  while IFS= read -r st; do
    [ -n "$st" ] && [ "$st" != "null" ] || continue
    dir="$(resolve_prereq_dir "$st")"
    [ -n "$dir" ] && D_PREREQS+=("$dir") \
      || print_warning "  prerequisite ServiceTemplate '$st' did not resolve to a chart dir — skipping"
  done < <(yq '.spec.prerequisites[]?.serviceTemplate.name' "$class")

  # Endpoints: HTTP -> curl, everything else (SSH/TCP) -> socket.
  local line name proto
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    name="${line%% *}"; proto="${line##* }"
    if [ "$proto" = "HTTP" ]; then D_HTTP+=("$name"); else D_TCP+=("$name"); fi
  done < <(yq '.spec.accessEndpoints[]? | .name + " " + .protocol' "$class")

  # Optional override.
  if [ -f "$ov" ]; then
    local v
    v="$(yq '.skip // "false"' "$ov")";   [ "$v" = "true" ] && D_SKIP="true"
    v="$(yq '.gpu // ""' "$ov")";         [ "$v" = "true" ] && D_GPU="1"; [ "$v" = "false" ] && D_GPU="0"
    v="$(yq '.vendor // ""' "$ov")";      [ -n "$v" ] && [ "$v" != "null" ] && D_VENDOR="$v"
    if yq -e '.prerequisites' "$ov" >/dev/null 2>&1; then
      D_PREREQS=(); while IFS= read -r dir; do [ -n "$dir" ] && D_PREREQS+=("$dir"); done < <(yq '.prerequisites[]' "$ov")
    fi
  fi
}

# ---- HTTP host for an endpoint (read from the WSD's resolved status.access)

access_host() { # access_host <endpoint>
  kubectl --context "$MGMT" -n "$NS" get wsd "$WSD_NAME" -o json 2>/dev/null \
    | jq -r --arg n "$1" '.status.access[]?|select(.name==$n)|.url' \
    | sed -E 's#^[a-z]+://##; s#/.*$##; s#:[0-9]+$##' | head -1
}

tcp_port() { # tcp_port <endpoint>
  kubectl --context "$MGMT" -n "$NS" get wsd "$WSD_NAME" -o json 2>/dev/null \
    | jq -r --arg n "$1" '.status.access[]?|select(.name==$n)|.url' \
    | sed 's#.*:##' | head -1
}

teardown_chart() { # teardown_chart <chart> <gpu> <vendor>
  CHART="$1" WSD_NAME="$WSD_NAME" NS="$NS" MGMT="$MGMT" "$DEV" down >/dev/null 2>&1 || true
  if [ "$2" = "1" ]; then
    VENDOR="$3" CHILD_CTX="$CHILD_CTX" "$DEV" unfake-gpu >/dev/null 2>&1 || true
  fi
}

# ---- One chart, end to end

test_chart() {
  local chart="$1"
  print_status "==== chart: ${chart} ===="
  derive_chart "$chart"
  if [ "$D_SKIP" = "true" ]; then print_warning "  skip (no WorkspaceClass or e2e.yaml skip:true)"; return 0; fi
  print_status "  derived: gpu=${D_GPU} vendor=${D_VENDOR} prereqs=[${D_PREREQS[*]:-}] http=[${D_HTTP[*]:-}] tcp=[${D_TCP[*]:-}]"

  # Clean slate for this chart's WSD name.
  CHART="$chart" WSD_NAME="$WSD_NAME" NS="$NS" MGMT="$MGMT" "$DEV" down >/dev/null 2>&1 || true

  # 1) Publish prerequisites (ServiceTemplate only — operator auto-installs).
  local p
  for p in "${D_PREREQS[@]:-}"; do
    [ -n "$p" ] || continue
    print_status "  publishing prerequisite: ${p}"
    if ! PREREQ="$p" "$DEV" publish-prereq >/dev/null 2>&1; then
      print_error "FAIL  ${chart}: publish prerequisite ${p}"; FAILED+=("${chart}: publish prereq ${p}"); FAIL=$((FAIL+1)); return 1
    fi
  done

  # 2) Fake a GPU on the target child when the class mandates one.
  if [ "$D_GPU" = "1" ]; then
    print_status "  faking ${D_VENDOR} GPU on ${CHILD_CTX}"
    VENDOR="$D_VENDOR" CHILD_CTX="$CHILD_CTX" "$DEV" fake-gpu >/dev/null 2>&1 || true
  fi

  # 3) Deploy the chart + its CRs + WSD through the operator.
  if ! CHART="$chart" WSD_NAME="$WSD_NAME" NS="$NS" CD="$CD" MGMT="$MGMT" \
       GPU="$D_GPU" VENDOR="$D_VENDOR" "$DEV" up >/dev/null 2>&1; then
    print_error "FAIL  ${chart}: deploy (workspace-dev.sh up)"; FAILED+=("${chart}: deploy"); FAIL=$((FAIL+1))
    teardown_chart "$chart" "$D_GPU" "$D_VENDOR"; return 1
  fi

  # 4) Assert: WSD reaches Running.
  if ! check "$RUN_TIMEOUT" "${chart}: WSD Running" \
     'kubectl --context $MGMT -n $NS get wsd $WSD_NAME -o json | jq -e ".status.phase==\"Running\"" >/dev/null'; then
    teardown_chart "$chart" "$D_GPU" "$D_VENDOR"; return 1
  fi

  # 5) Assert: routing programmed.
  check "$SETTLE" "${chart}: RoutesReady=True" \
    'kubectl --context $MGMT -n $NS get wsd $WSD_NAME -o json | jq -e ".status.conditions[]?|select(.type==\"RoutesReady\")|.status==\"True\"" >/dev/null'

  discover_lb || true

  # 6) HTTP endpoints — resolved hostname + live curl through the gateway LB.
  local ep host
  for ep in "${D_HTTP[@]:-}"; do
    [ -n "$ep" ] || continue
    check "$SETTLE" "${chart}: access[${ep}] hostname resolved + ready" \
      'kubectl --context $MGMT -n $NS get wsd $WSD_NAME -o json | jq -e ".status.access[]?|select(.name==\"'"$ep"'\")|(.url|startswith(\"http\")) and .ready==true" >/dev/null'
    host="$(access_host "$ep")"
    if [ -z "$host" ]; then
      print_error "FAIL  ${chart}: access[${ep}] no url in status"; FAILED+=("${chart}: ${ep} no url"); FAIL=$((FAIL+1)); continue
    fi
    # A 2xx/3xx/4xx proves the mesh routed to a LIVE backend that answered;
    # 000 (no route/connection) and 5xx (502/503/504 no-healthy-upstream) fail.
    check "$RUN_TIMEOUT" "${chart}: curl ${ep} (${host}) reaches a live backend over the mesh" \
      'code=$(curl -s -m 5 -o /dev/null -w "%{http_code}" -H "Host: '"$host"'" "http://'"$LB_IP"'/"); case "$code" in 2*|3*|4*) true;; *) echo "http $code"; false;; esac'
  done

  # 7) SSH/TCP endpoints — pool port allocated + reachable at the gateway LB.
  local port
  for ep in "${D_TCP[@]:-}"; do
    [ -n "$ep" ] || continue
    check "$SETTLE" "${chart}: access[${ep}] TCP pool port allocated + ready" \
      'kubectl --context $MGMT -n $NS get wsd $WSD_NAME -o json | jq -e ".status.access[]?|select(.name==\"'"$ep"'\")|(.url|test(\":[0-9]+$\")) and .ready==true" >/dev/null'
    port="$(tcp_port "$ep")"
    if [ -z "$port" ] || ! [ "$port" -gt 0 ] 2>/dev/null; then
      print_error "FAIL  ${chart}: access[${ep}] no pool port"; FAILED+=("${chart}: ${ep} no port"); FAIL=$((FAIL+1)); continue
    fi
    check "$SHORT" "${chart}: ${ep} port ${port} open at gateway LB" \
      'timeout 3 bash -c "echo > /dev/tcp/'"$LB_IP"'/'"$port"'"'
  done

  # 8) Teardown this chart (keep the env for the next chart).
  print_status "  tearing down ${chart}"
  teardown_chart "$chart" "$D_GPU" "$D_VENDOR"
}

main() {
  build_chart_index
  preflight

  local charts; charts="$(changed_charts)"
  if [ -z "$charts" ]; then
    print_warning "No changed charts detected (BASE_REF=${BASE_REF}). Nothing to test."
    exit 0
  fi
  print_status "Changed charts:"; printf '  - %s\n' $charts

  local c
  for c in $charts; do
    [ -d "workspace-templates/${c}/exalsius" ] || { print_warning "skip ${c}: no exalsius/ CRs"; continue; }
    test_chart "$c"
  done

  echo
  print_status "==== SUMMARY ===="
  echo "  ${PASS} passed, ${FAIL} failed"
  if [ "$FAIL" -gt 0 ]; then
    local f; for f in "${FAILED[@]}"; do print_error "  FAILED: ${f}"; done
    exit 1
  fi
  print_success "Chart E2E passed (${PASS} checks)"
}

# Run main only when executed directly (sourcing exposes the functions for tests).
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
