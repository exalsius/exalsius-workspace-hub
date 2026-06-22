# Decouple a workspace chart's image tag from its chart version

Workspace charts pin their container image by an explicit, immutable reference in
`values.yaml` (`image.repository` + `image.tag` + `image.digest`), **independent**
of the chart's own SemVer. A chart must not derive the running image from
`.Chart.AppVersion` (and we drop `appVersion` from `Chart.yaml` entirely, so there
is no misleading number that tracks the chart instead of the app).

**Why.** The container images are built in a separate repository on their own
cadence. Coupling the image to the chart version (e.g. `image.tag | default
.Chart.AppVersion`, as the jupyter-notebook chart originally did) forces lockstep
releases: a chart-only fix would demand an identical re-tagged image, and an
image-only rebuild (e.g. a CVE patch) would have no chart version to carry it.
Decoupling lets each move on its own clock. Re-pinning the image is still a normal
`values.yaml` change and so still produces a chart patch release — the chart
remains the single place that records *which* image runs — but the image keeps its
own versioning scheme.

**Immutability.** The pin's immutability comes from the `@sha256:<digest>`, not the
tag. A bare moving tag (`:latest`, `:latest-nvidia`) is forbidden; `:latest@sha256:<digest>`
is fine — the digest makes it reproducible and the tag is only a human-readable label.

Applies to all workspace charts (jupyter-notebook and marimo adopt it together).
