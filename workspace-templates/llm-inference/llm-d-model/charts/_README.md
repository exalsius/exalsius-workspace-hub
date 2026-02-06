**Note:** The dependency charts (inferencepool, llm-d-modelservice) have been modified in their `_helpers.tpl`.

**inferencepool:** The inference extension name and cluster RBAC name now honour `global.deploymentName` when set. If the parent provides `global.deploymentName`, it is used as the base for the extension name (still truncated to 40 chars) and the suffix `-epp` is appended via a new `safeName` helper. Without `global.deploymentName`, behaviour is unchanged (base from `Release.Name`).

**llm-d-modelservice:** The fullname helper now honours `global.deploymentName` when set. If the parent provides it, the fullname is built with a new `safeName` helper using that base and the suffix `-ms` (truncated to 55 chars). Existing behaviour is unchanged when `global.deploymentName` is not set (fullnameOverride, or Release.Name / chart name logic).

This allows umbrella deployments to use a single deployment name (e.g. from exalsius) for both the inference pool and the model service.
