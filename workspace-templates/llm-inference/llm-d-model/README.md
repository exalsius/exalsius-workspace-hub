<p align="center"><img src="../../../docs/img/logo_banner.png" alt="exalsius banner" width="250"></p>

# LLM-D Model Workspace

This workspace provides a Helm chart for deploying an LLM model for inference using the [llm-d](https://llm-d.ai/) stack. It combines the [Gateway API Inference Extension](https://gateway-api-inference-extension.sigs.k8s.io/) inference pool with the [llm-d-modelservice](https://llm-d.ai/docs/architecture/Components/modelservice) to serve vLLM models behind the llm-d inference gateway.

## Prerequisites

- A running Kubernetes cluster.
- The [llm-d-infra](../llm-d-infra) umbrella chart deployed (inference gateway, body-based routing, model discovery).

## Quickstart

### Using the exalsius CLI

The recommended way to deploy this workspace is with the `exls` command-line tool.

```sh
exls workspace deploy llm-inference <CLI parameters>
```

### Using Helm

You can also deploy the workspace directly using Helm.

1. **Clone the repository:**
   ```sh
   git clone https://github.com/exalsius/exalsius-workspace-hub.git
   cd exalsius-workspace-templates/workspace-templates
   ```

2. **Install the chart:**
   ```sh
   helm install my-llm-model ./llm-inference/llm-d-model \
     --set huggingfaceToken=<your-hf-token> \
     --set ms.modelArtifacts.uri="hf://Qwen/Qwen3-1.7B" \
     --set ms.modelArtifacts.name="Qwen/Qwen3-1.7B" \
     --set ms.modelArtifacts.labels."llm-d\.ai/model"="Qwen3-1.7B" \
     --set ip.inferencePool.modelServers.matchLabels."llm-d\.ai/model"="Qwen3-1.7B"
   ```

## Configuration

All configurable options are defined in the `values.yaml` file and can be overridden through `exls` CLI flags or Helm parameters. For full configuration options, see the documentation of the child charts: [inferencepool](https://gateway-api-inference-extension.sigs.k8s.io/api-types/inferencepool/) and [llm-d-modelservice](https://llm-d.ai/docs/architecture/Components/modelservice).

### Required Configuration

These values must be set when deploying a model. The inference pool selector and model artifact labels must match so that the gateway routes traffic correctly.

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `huggingfaceToken` | **Required.** Hugging Face token for downloading models (stored in a Kubernetes secret). | `""` |
| `ms.modelArtifacts.uri` | **Required.** Hugging Face URI for the model (e.g. `hf://Qwen/Qwen3-1.7B`). | `"hf://Qwen/Qwen3-1.7B"` |
| `ms.modelArtifacts.name` | **Required.** Display name for the model. | `"Qwen/Qwen3-1.7B"` |
| `ms.modelArtifacts.labels` | **Required.** Labels for the model deployment. Must include `llm-d.ai/model` to match the inference pool. | See values.yaml |
| `ip.inferencePool.modelServers.matchLabels` | **Required.** Labels to select model server pods. Must match `ms.modelArtifacts.labels` (same `llm-d.ai/model` value). | See values.yaml |
