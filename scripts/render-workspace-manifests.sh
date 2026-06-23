#!/usr/bin/env bash
# Render a workspace chart's exalsius/ templates into the version-pinned,
# version-pinned manifests tree (applied to the management cluster).
#
# For chart <name> at version <v> (from Chart.yaml), this writes:
#   manifests/<name>/<v>/servicetemplate.yaml   (applied to the management cluster)
#   manifests/<name>/<v>/workspaceclass.yaml    (applied to the management cluster)
#   examples/<name>/<v>/example-workspacedeployment.yaml  (docs only, NOT applied)
#
# Placeholders substituted: ${VERSION} (SemVer) and ${VERSION_DASHED} (dots->dashes).
# Idempotent: a chart with no exalsius/ dir is skipped.
#
# Usage: scripts/render-workspace-manifests.sh <chart-dir>
#   e.g. scripts/render-workspace-manifests.sh workspace-templates/jupyter-notebook
set -euo pipefail

chart_dir="${1:?usage: render-workspace-manifests.sh <chart-dir>}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

chart_dir="${chart_dir%/}"
exalsius_dir="$chart_dir/exalsius"
if [ ! -d "$exalsius_dir" ]; then
  echo "skip: $chart_dir has no exalsius/ directory"
  exit 0
fi

name="$(yq '.name' "$chart_dir/Chart.yaml")"
version="$(yq '.version' "$chart_dir/Chart.yaml")"
version_dashed="${version//./-}"

# Cross-chart prerequisite reference: a chart whose WorkspaceClass lists a
# sibling chart as a prerequisite (e.g. llm-d-model -> llm-d-infra) pins the
# sibling's exact ServiceTemplate version via ${INFRA_VERSION[_DASHED]}, which
# the per-chart ${VERSION} cannot express. Resolve it from the sibling
# llm-d-infra Chart.yaml when present; otherwise leave the placeholder so a
# stray reference fails loudly at apply time rather than rendering wrong.
infra_chart="$(dirname "$chart_dir")/llm-d-infra/Chart.yaml"
if [ -f "$infra_chart" ]; then
  infra_version="$(yq '.version' "$infra_chart")"
  infra_version_dashed="${infra_version//./-}"
else
  infra_version=""
  infra_version_dashed=""
fi

mani_dir="manifests/$name/$version"
ex_dir="examples/$name/$version"
mkdir -p "$mani_dir" "$ex_dir"

render() {
  sed \
    -e "s/\${VERSION_DASHED}/$version_dashed/g" -e "s/\${VERSION}/$version/g" \
    -e "s/\${INFRA_VERSION_DASHED}/$infra_version_dashed/g" \
    -e "s/\${INFRA_VERSION}/$infra_version/g" \
    "$1"
}

for f in servicetemplate workspaceclass; do
  src="$exalsius_dir/$f.yaml"
  [ -f "$src" ] && render "$src" > "$mani_dir/$f.yaml"
done

ex_src="$exalsius_dir/example-workspacedeployment.yaml"
[ -f "$ex_src" ] && render "$ex_src" > "$ex_dir/example-workspacedeployment.yaml"

echo "rendered $name@$version -> $mani_dir/ and $ex_dir/"
