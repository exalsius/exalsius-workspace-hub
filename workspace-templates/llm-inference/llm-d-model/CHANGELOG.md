# Changelog

## [1.0.0](https://github.com/exalsius/exalsius-workspace-hub/compare/llm-d-model-v0.3.0...llm-d-model-v1.0.0) (2026-08-27)


### ⚠ BREAKING CHANGES

* **llm-d-model:** model discovery no longer works against an llm-d-infra older than the release that admits AgentgatewayModel on its internal listener.
* **llm-d-model:** values move from `ms.*` and `ip.*` to `model.*`, `modelServer.*` and `igw.*`; `ms.modelArtifacts.uri` collapses into `model.name` with `model.source.claimName` replacing the `pvc://` form. The WorkspaceClass drops `resourceInjection`, and the workload is a LeaderWorkerSet rather than a Deployment, which needs the controller from llm-d-infra.

### Features

* **llm-d-model:** add opt-in OpenAI tool calling ([c161baf](https://github.com/exalsius/exalsius-workspace-hub/commit/c161baf93fa31f9f756d08782ecfc520353482fa))
* **llm-d-model:** rebuild on the llm-d router chart with an owned LeaderWorkerSet ([2179974](https://github.com/exalsius/exalsius-workspace-hub/commit/2179974e74684ebe323944243150c01c3493739d))
* **llm-d-model:** route the internal listener via AgentgatewayModel ([1ac7a9a](https://github.com/exalsius/exalsius-workspace-hub/commit/1ac7a9a0c59e1a01fefe3d277f64fa23e7fa9614))
* **llm-d-model:** run llm-d's vLLM build instead of upstream ([47cbf2c](https://github.com/exalsius/exalsius-workspace-hub/commit/47cbf2ce8780fffbb3cb9693b4714b3c2e11505b))

## [0.3.0](https://github.com/exalsius/exalsius-workspace-hub/compare/llm-d-model-v0.2.0...llm-d-model-v0.3.0) (2026-07-07)


### Features

* add llm-d-model umbrella helm chart ([#69](https://github.com/exalsius/exalsius-workspace-hub/issues/69)) ([bf4b0a9](https://github.com/exalsius/exalsius-workspace-hub/commit/bf4b0a9d51d0019cee10b368ca8f724073419716))
* align workspace templates with llm-d 0.6.0 ([#82](https://github.com/exalsius/exalsius-workspace-hub/issues/82)) ([53b6478](https://github.com/exalsius/exalsius-workspace-hub/commit/53b6478f2cd1c9782f42f5c24a96be4f93f8c665))
* llm-d versioning ([#75](https://github.com/exalsius/exalsius-workspace-hub/issues/75)) ([8567ab4](https://github.com/exalsius/exalsius-workspace-hub/commit/8567ab4c17dfbcfae67a8dddc193da5823119735))
* refine llm-d-infra ([#71](https://github.com/exalsius/exalsius-workspace-hub/issues/71)) ([5e35c0e](https://github.com/exalsius/exalsius-workspace-hub/commit/5e35c0ef5ecf4500797b29bc8f1dd1f9c3e5464c))
* update llm-d-model to v0.5.0 ([#72](https://github.com/exalsius/exalsius-workspace-hub/issues/72)) ([64d4879](https://github.com/exalsius/exalsius-workspace-hub/commit/64d48791230106128fb2b4f152dd379346860275))


### Bug Fixes

* extend json validation of child chart ([#76](https://github.com/exalsius/exalsius-workspace-hub/issues/76)) ([cbd90ca](https://github.com/exalsius/exalsius-workspace-hub/commit/cbd90ca145754fccc1faac91a19a78310ac189b5))
* **llm-inference:** make mount of api-key optional ([#84](https://github.com/exalsius/exalsius-workspace-hub/issues/84)) ([3b34ae4](https://github.com/exalsius/exalsius-workspace-hub/commit/3b34ae43bc3a3531e1a0a7f0b4aac728fc381927))
* **llm-inference:** remove legacy gaie flag ([d62dec7](https://github.com/exalsius/exalsius-workspace-hub/commit/d62dec7678ba9cedf90d8a3086b6b79c1ef9609d))
* **workspaces:** handle unsupported display driver / cuda driver combination in llm-d-cuda image ([#77](https://github.com/exalsius/exalsius-workspace-hub/issues/77)) ([c8e1cb8](https://github.com/exalsius/exalsius-workspace-hub/commit/c8e1cb86b474aa6bb8f9e2ccb33ba7befdd854ac))
