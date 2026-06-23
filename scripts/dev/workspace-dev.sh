#!/usr/bin/env bash
# Local chart-iteration harness for workspace templates.
#
# Packages a single chart, pushes it to the local-dev-env kind registry, and
# drives it through the FULL operator path (HelmRepository -> ServiceTemplate ->
# WorkspaceClass -> WorkspaceDeployment) so you can iterate on the chart and its
# exalsius/ CRs against real clusters. The exalsius/ manifests are rendered on
# the fly at the chart's current Chart.yaml version, so editing the
# ServiceTemplate/WorkspaceClass templates is tested too.
#
# Assumes local-dev-env `make up` + `make setup-kcm-regional-child` have run
# (mgmt + regional + child clusters, source-controller, and the tenant Gateway).
#
# Commands: up | redeploy | down | fake-gpu | unfake-gpu
# Config via env (see Makefile for the make-target wrappers and defaults):
#   CHART (default jupyter-notebook)  MGMT (kind-exalsius)  CHILD_CTX (kind-child-adopted-1)
#   CD (default-child-adopted-1)  NS (kcm-system)  WSD_NAME (dev)
#   GPU (0|1)  VENDOR (nvidia|amd)  IMAGE_REPO  IMAGE_TAG  REGISTRY_HOST (localhost:5050)
set -euo pipefail

CMD="${1:?usage: workspace-dev.sh <up|redeploy|down|fake-gpu|unfake-gpu>}"

CHART="${CHART:-jupyter-notebook}"
MGMT="${MGMT:-kind-exalsius}"
CHILD_CTX="${CHILD_CTX:-kind-child-adopted-1}"
CD="${CD:-default-child-adopted-1}"
NS="${NS:-kcm-system}"
WSD_NAME="${WSD_NAME:-dev}"
GPU="${GPU:-0}"
VENDOR="${VENDOR:-nvidia}"
IMAGE_REPO="${IMAGE_REPO:-}"
IMAGE_TAG="${IMAGE_TAG:-}"
REGISTRY_HOST="${REGISTRY_HOST:-localhost:5050}"
HELMREPO="exalsius-workspace-hub"
REG_CTX="${REG_CTX:-kind-regional-adopted}"
GW_NS="${GW_NS:-exalsius-gateway}"
GW_SVC="${GW_SVC:-exalsius-workspaces-istio}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

CHART_DIR="workspace-templates/${CHART}"
EXALSIUS_DIR="${CHART_DIR}/exalsius"
TMP_DIR="${REPO_ROOT}/.dev-tmp/${CHART}"

require_chart() {
  [ -f "${CHART_DIR}/Chart.yaml" ] || { echo "error: no chart at ${CHART_DIR}"; exit 1; }
  [ -d "${EXALSIUS_DIR}" ] || {
    echo "error: ${CHART_DIR} has no exalsius/ directory (ServiceTemplate + WorkspaceClass + example WSD)."
    echo "       Only charts that ship exalsius/ manifests can be driven through the operator path."
    exit 1
  }
}

# Populated by load_chart_meta.
NAME=""; VERSION=""; VERSION_DASHED=""; WSC_NAME=""; ST_NAME=""
load_chart_meta() {
  NAME="$(yq '.name' "${CHART_DIR}/Chart.yaml")"
  VERSION="$(yq '.version' "${CHART_DIR}/Chart.yaml")"
  VERSION_DASHED="${VERSION//./-}"
  WSC_NAME="${NAME}-${VERSION_DASHED}"
  ST_NAME="${NAME}-${VERSION_DASHED}"
}

# nvidia.com/gpu.product=NVIDIA-L40 / amd.com/gpu.device-id=74a1, matched by both
# the faked node label and the WorkspaceDeployment's gpuNodeSelector.
gpu_label_key() { [ "${VENDOR}" = "amd" ] && echo "amd.com/gpu.device-id" || echo "nvidia.com/gpu.product"; }
gpu_label_val() { [ "${VENDOR}" = "amd" ] && echo "74a1" || echo "NVIDIA-L40"; }
gpu_resource()  { [ "${VENDOR}" = "amd" ] && echo "amd.com/gpu" || echo "nvidia.com/gpu"; }

require_registry() {
  curl -fsS -m 5 "http://${REGISTRY_HOST}/v2/" >/dev/null 2>&1 || {
    echo "error: kind registry at ${REGISTRY_HOST} unreachable; is local-dev-env up?"; exit 1; }
}

push_chart() {
  require_registry
  mkdir -p "${TMP_DIR}"
  echo ">> packaging + pushing ${NAME}:${VERSION} to oci://${REGISTRY_HOST}/charts"
  helm package "${CHART_DIR}" -d "${TMP_DIR}" >/dev/null
  helm push "${TMP_DIR}/${NAME}-${VERSION}.tgz" "oci://${REGISTRY_HOST}/charts" --plain-http
  rm -f "${TMP_DIR}/${NAME}-${VERSION}.tgz"
}

reconcile_source() {
  echo ">> poking HelmRepository/${HELMREPO} to re-pull the chart"
  kubectl --context "${MGMT}" -n "${NS}" annotate helmrepository "${HELMREPO}" \
    "reconcile.fluxcd.io/requestedAt=$(date +%s)" --overwrite >/dev/null
}

render_and_apply_crs() {
  mkdir -p "${TMP_DIR}"
  for f in servicetemplate workspaceclass; do
    sed -e "s/\${VERSION_DASHED}/${VERSION_DASHED}/g" -e "s/\${VERSION}/${VERSION}/g" \
      "${EXALSIUS_DIR}/${f}.yaml" > "${TMP_DIR}/${f}.yaml"
  done
  echo ">> applying ServiceTemplate + WorkspaceClass (${WSC_NAME})"
  kubectl --context "${MGMT}" apply -f "${TMP_DIR}/servicetemplate.yaml"
  kubectl --context "${MGMT}" apply -f "${TMP_DIR}/workspaceclass.yaml"
}

# Builds the WSD by patching the chart's example WSD: reuse its chart-specific
# spec.values (e.g. notebookPassword), but own the topology (CD/NS/class) and
# GPU/image choices from the harness flags.
apply_wsd() {
  local key val res
  WSD_FILE="${TMP_DIR}/workspacedeployment.yaml"
  WSD_NAME="${WSD_NAME}" NS="${NS}" WSC_NAME="${WSC_NAME}" CD="${CD}" \
  yq '
    .metadata.name = strenv(WSD_NAME) |
    .metadata.namespace = strenv(NS) |
    .spec.workspaceClassRef = strenv(WSC_NAME) |
    .spec.clusterDeploymentRef.name = strenv(CD) |
    .spec.clusterDeploymentRef.namespace = strenv(NS)
  ' "${EXALSIUS_DIR}/example-workspacedeployment.yaml" > "${WSD_FILE}"

  if [ "${GPU}" = "1" ]; then
    key="$(gpu_label_key)"; val="$(gpu_label_val)"
    GKEY="${key}" GVAL="${val}" yq -i '
      .spec.resources.perReplica.gpuCount = 1 |
      .spec.resources.perReplica.gpuNodeSelector = {strenv(GKEY): strenv(GVAL)}
    ' "${WSD_FILE}"
  else
    yq -i 'del(.spec.resources.perReplica.gpuCount) | del(.spec.resources.perReplica.gpuNodeSelector)' "${WSD_FILE}"
  fi

  # Image override targets the vendor-keyed image map (image.<variant>.*) the
  # GPU-workspace charts use (ADR-0003). The chart selects image.amd only when
  # the injected gpuVendor is AMD (GPU=1 VENDOR=amd); otherwise image.default —
  # so override the variant the chart will actually pick. Clear that variant's
  # pinned digest (so a moving override tag pulls) and force Always so redeploys
  # re-pull a moving tag.
  if [ -n "${IMAGE_REPO}" ] || [ -n "${IMAGE_TAG}" ]; then
    if [ "${GPU}" = "1" ] && [ "${VENDOR}" = "amd" ]; then
      yq -i '.spec.values.image.amd.digest = "" | .spec.values.image.pullPolicy = "Always"' "${WSD_FILE}"
      [ -n "${IMAGE_REPO}" ] && IMG="${IMAGE_REPO}" yq -i '.spec.values.image.amd.repository = strenv(IMG)' "${WSD_FILE}"
      [ -n "${IMAGE_TAG}" ]  && IMG="${IMAGE_TAG}"  yq -i '.spec.values.image.amd.tag = strenv(IMG)' "${WSD_FILE}"
    else
      yq -i '.spec.values.image.default.digest = "" | .spec.values.image.pullPolicy = "Always"' "${WSD_FILE}"
      [ -n "${IMAGE_REPO}" ] && IMG="${IMAGE_REPO}" yq -i '.spec.values.image.default.repository = strenv(IMG)' "${WSD_FILE}"
      [ -n "${IMAGE_TAG}" ]  && IMG="${IMAGE_TAG}"  yq -i '.spec.values.image.default.tag = strenv(IMG)' "${WSD_FILE}"
    fi
  fi

  echo ">> applying WorkspaceDeployment ${WSD_NAME} (cluster ${CD}, gpu=${GPU})"
  kubectl --context "${MGMT}" apply -f "${WSD_FILE}"
}

child_node() { kubectl --context "${CHILD_CTX}" get nodes -o jsonpath='{.items[0].metadata.name}'; }

case "${CMD}" in
  up)
    require_chart; load_chart_meta
    push_chart
    kubectl --context "${MGMT}" apply -f "${REPO_ROOT}/scripts/dev/helm-repository.yaml"
    reconcile_source
    render_and_apply_crs
    apply_wsd
    cat <<EOF

Deployed. Watch it come up:
  kubectl --context ${MGMT} -n ${NS} get wsd ${WSD_NAME} -w
  kubectl --context ${CHILD_CTX} -n ws-${WSD_NAME} get deploy,pod,svc,pvc

Access the workspace (HTTP) — the tenant Gateway is a LoadBalancer via cloud-provider-kind:
  # resolved URL(s) for this workspace (read the host from here):
  kubectl --context ${MGMT} -n ${NS} get wsd ${WSD_NAME} -o jsonpath='{.status.access}' | jq .
  # the Gateway's external IP on the regional cluster:
  GW_IP=\$(kubectl --context ${REG_CTX} -n ${GW_NS} get svc ${GW_SVC} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  curl -iL -H "Host: ${WSD_NAME}.exalsius.local" "http://\$GW_IP/"
  # (or: echo "\$GW_IP ${WSD_NAME}.exalsius.local" | sudo tee -a /etc/hosts; then open in a browser)

  503 'no healthy upstream' = route OK but backend not ready. Isolate from the mesh:
  kubectl --context ${CHILD_CTX} -n ws-${WSD_NAME} get pod   # must be READY 1/1
  kubectl --context ${CHILD_CTX} -n ws-${WSD_NAME} port-forward svc/wsd-${CD}-${WSD_NAME}-http 8888:80
  curl -i localhost:8888/

Iterate after editing the chart:   make dev-redeploy
Tear down:                          make dev-down
EOF
    # SSH/TCP endpoints route via the tenant Gateway's TCP port pool (raw TCP,
    # by PORT not hostname) — a different path from the HTTP block above.
    if yq -e '.spec.accessEndpoints[] | select(.protocol != "HTTP")' "${TMP_DIR}/workspaceclass.yaml" >/dev/null 2>&1; then
      ssh_ep="$(yq '.spec.accessEndpoints[] | select(.protocol != "HTTP") | .name' "${TMP_DIR}/workspaceclass.yaml" | head -1)"
      ssh_port="$(yq '.spec.accessEndpoints[] | select(.protocol != "HTTP") | .port' "${TMP_DIR}/workspaceclass.yaml" | head -1)"
      cat <<EOF

Access the '${ssh_ep}' endpoint (SSH/TCP) — routed via the tenant Gateway's TCP
port pool (raw TCP, so by allocated PORT, not hostname). Read the operator-
assigned port once routing is programmed:
  kubectl --context ${MGMT} -n ${NS} get wsd ${WSD_NAME} -o jsonpath='{.status.access}' | jq .
  # -> {"name":"${ssh_ep}","protocol":"SSH","url":"ssh://<domain>:<port>","ready":true}

  GW_IP=\$(kubectl --context ${REG_CTX} -n ${GW_NS} get svc ${GW_SVC} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p <port> root@\$GW_IP
  # auth comes from the WSD's spec.values (sshPassword / sshPublicKey)

  ready:false? read .message (port pool exhausted / TCPRoute CRD missing).
  Isolate the pod's sshd from routing by port-forwarding the child Service:
  kubectl --context ${CHILD_CTX} -n ws-${WSD_NAME} port-forward svc/wsd-${CD}-${WSD_NAME}-${ssh_ep} 2222:${ssh_port}
  ssh -o StrictHostKeyChecking=no -p 2222 root@localhost
EOF
    fi
    ;;
  redeploy)
    require_chart; load_chart_meta
    push_chart
    reconcile_source
    echo ">> recreating WorkspaceDeployment ${WSD_NAME} for a clean redeploy"
    kubectl --context "${MGMT}" -n "${NS}" delete wsd "${WSD_NAME}" --ignore-not-found --wait=true
    apply_wsd
    echo ">> done. kubectl --context ${MGMT} -n ${NS} get wsd ${WSD_NAME} -w"
    ;;
  down)
    require_chart; load_chart_meta
    kubectl --context "${MGMT}" -n "${NS}" delete wsd "${WSD_NAME}" --ignore-not-found
    kubectl --context "${MGMT}" delete workspaceclass "${WSC_NAME}" --ignore-not-found
    kubectl --context "${MGMT}" -n "${NS}" delete servicetemplate "${ST_NAME}" --ignore-not-found
    kubectl --context "${MGMT}" delete -f "${REPO_ROOT}/scripts/dev/helm-repository.yaml" --ignore-not-found
    echo ">> torn down ${CHART} (${WSC_NAME})"
    ;;
  fake-gpu)
    node="$(child_node)"; key="$(gpu_label_key)"; val="$(gpu_label_val)"; res="$(gpu_resource)"
    echo ">> faking ${VENDOR} GPU on ${CHILD_CTX}/${node} (${key}=${val}, ${res}=1)"
    kubectl --context "${CHILD_CTX}" label node "${node}" "${key}=${val}" --overwrite
    kubectl --context "${CHILD_CTX}" patch node "${node}" --subresource=status --type=json -p \
      "[{\"op\":\"add\",\"path\":\"/status/capacity/${res//\//~1}\",\"value\":\"1\"},{\"op\":\"add\",\"path\":\"/status/allocatable/${res//\//~1}\",\"value\":\"1\"}]"
    echo ">> now: make dev-up GPU=1 VENDOR=${VENDOR}"
    ;;
  unfake-gpu)
    node="$(child_node)"; key="$(gpu_label_key)"; res="$(gpu_resource)"
    echo ">> removing faked ${VENDOR} GPU on ${CHILD_CTX}/${node}"
    kubectl --context "${CHILD_CTX}" label node "${node}" "${key}-" >/dev/null 2>&1 || true
    kubectl --context "${CHILD_CTX}" patch node "${node}" --subresource=status --type=json -p \
      "[{\"op\":\"remove\",\"path\":\"/status/capacity/${res//\//~1}\"},{\"op\":\"remove\",\"path\":\"/status/allocatable/${res//\//~1}\"}]" >/dev/null 2>&1 || true
    ;;
  *)
    echo "unknown command: ${CMD}"; exit 1 ;;
esac
