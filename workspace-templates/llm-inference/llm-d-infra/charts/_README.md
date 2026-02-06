**Note:** The archived chart `body-based-routing-v1.3.0.tgz` has been modified.

We extended the `istio.yaml` template to optionally configure a **workloadSelector** via `values.yaml`. When `provider.istio.workloadSelector` is set (as a map of labels), the EnvoyFilter is applied only to workloads (e.g. gateway pods) that match those labels. If omitted or empty, the filter applies to all workloads in the release namespace.

This allows restricting the body-based routing EnvoyFilter to the inference gateway only, by passing labels that match the gateway deployment (e.g. `gateway-role: llm-inference`).
