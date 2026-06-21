#!/usr/bin/env bash
# Validate the release-please config against the actual charts.
#
# Catches the classes of mistake that make release-please fail or misbehave:
#   - malformed release-please-config.json / .release-please-manifest.json
#   - a package key present in one file but not the other
#   - a configured package whose chart directory / Chart.yaml is missing
#   - a Chart.yaml version that disagrees with the seeded manifest version
#
# Runs in CI (validate-release-config.yaml) and locally. Needs jq + yq.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

cfg="release-please-config.json"
man=".release-please-manifest.json"
fail=0
err() { echo "::error::$*"; fail=1; }

jq -e . "$cfg" >/dev/null || { echo "::error::$cfg is not valid JSON"; exit 1; }
jq -e . "$man" >/dev/null || { echo "::error::$man is not valid JSON"; exit 1; }

# Package keys must be identical in both files.
if ! diff <(jq -r '.packages | keys[]' "$cfg" | sort) \
          <(jq -r 'keys[]' "$man" | sort) >/dev/null; then
  err "package keys differ between $cfg and $man:"
  diff <(jq -r '.packages | keys[]' "$cfg" | sort) \
       <(jq -r 'keys[]' "$man" | sort) || true
fi

# Every configured package must point at a real chart whose version matches.
while IFS= read -r p; do
  if [ ! -f "$p/Chart.yaml" ]; then
    err "$cfg references '$p' but '$p/Chart.yaml' does not exist"
    continue
  fi
  cv="$(yq '.version' "$p/Chart.yaml")"
  mv="$(jq -r --arg k "$p" '.[$k] // ""' "$man")"
  if [ -z "$cv" ] || [ "$cv" = "null" ]; then
    err "$p/Chart.yaml has no .version"
  elif [ "$cv" != "$mv" ]; then
    err "$p: Chart.yaml version ($cv) != manifest version ($mv)"
  fi
done < <(jq -r '.packages | keys[]' "$cfg")

if [ "$fail" -ne 0 ]; then
  echo "release-please config validation FAILED"
  exit 1
fi
echo "release-please config OK ($(jq -r '.packages | keys | length' "$cfg") packages)"
