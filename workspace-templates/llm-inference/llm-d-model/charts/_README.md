**Note:** The dependency charts (inferencepool, llm-d-modelservice) are vendored and have custom naming changes in their helpers.

**inferencepool (v1.4.0):** The inference extension name, cluster RBAC name, and InferencePool resource name now honor `global.deploymentName` when set. If the parent provides `global.deploymentName`, it is used as the base for the extension name (still truncated to 40 chars) and the suffix `-epp` is appended via a `safeName` helper. The same deployment name is also used for the InferencePool metadata name and EPP `--pool-name` argument. Without `global.deploymentName`, behavior is unchanged (base from `Release.Name`).

**llm-d-modelservice (v0.4.9):** The fullname helper now honors `global.deploymentName` when set. If the parent provides it, the fullname is built with a `safeName` helper using that base and the suffix `-ms` (truncated to 55 chars). Existing behavior is unchanged when `global.deploymentName` is not set (`fullnameOverride`, or `Release.Name` / chart name logic).

**Schema updates:** The modelservice schema includes `global.deploymentName` and `global.deploymentNamespace` so these values validate when passed from the parent chart.
