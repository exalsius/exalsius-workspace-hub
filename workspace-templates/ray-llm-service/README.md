<p align="center"><img src="../../docs/img/logo_banner.png" alt="exalsius banner" width="250"></p>

# Ray LLM Service Workspace

This workspace provides a Helm chart for deploying a Large Language Model (LLM) serving environment on Kubernetes using [Ray Serve](https://docs.ray.io/en/latest/serve/index.html). 
It is designed for quickly setting up a scalable and efficient LLM inference service. 
This template automates the deployment of a Ray cluster and the LLM, making it easy to get started.

## Prerequisites

- A running Kubernetes cluster.
- The [KubeRay operator](https://github.com/ray-project/kuberay) installed in your cluster.

## Quickstart

### Using the exalsius CLI

The recommended way to deploy this workspace is with the `exls` command-line tool. You can specify the model you want to serve and other configurations.

```sh
exls workspace deploy llm-inference <CLI parameters>
```

### Using Helm

You can also deploy the workspace directly using Helm.

1.  **Clone the repository:**
    ```sh
    git clone https://github.com/exalsius/exalsius-workspace-hub.git
    cd exalsius-workspace-templates/workspace-templates
    ```

2.  **Install the chart:**
    ```sh
    helm install my-llm-service ./ray-llm-service --set llmModelName="mistralai/Mistral-7B-v0.1" --set huggingFaceToken=<your-hf-token>
    ```

## Configuration

All configurable options are defined in the `values.yaml` file and can be overridden through `exls` CLI flags or Helm parameters.

### Global Configuration

**Note:** These values are typically set automatically by exalsius and are only shown here for reference or local testing.

| Parameter             | Description                                       | Default Value                |
| --------------------- | ------------------------------------------------- | ---------------------------- |
| `global.deploymentName`      | **Required.** The name of the RayService deployment.            | `my-llm-service`             |
| `global.deploymentNamespace` | **Required.** The Kubernetes namespace for the deployment.      | `default`                    |

### Deployment Configuration

| Parameter             | Description                                                            | Default Value                   |
| --------------------- | ---------------------------------------------------------------------- | ------------------------------- |
| `deploymentImage`     | **Required.** The Docker image for the Ray service.                                  | `rayproject/ray-ml:2.46.0.0e19ea` |
| `deploymentNumReplicas` | **Required.** Number of deployment replicas. DO NOT CHANGE THIS PARAMETER. | `1` (constant) |
| `ephemeralStorageGb` | **Required.** The amount of ephemeral storage in GB for the pod. | `50`          |
| `huggingfaceToken`    | **Optional.** Your Hugging Face token for accessing private models.    | `""`                            |

### Ray and LLM Configuration

| Parameter                       | Description                                                          | Default Value                             |
| ------------------------------- | -------------------------------------------------------------------- | ----------------------------------------- |
| `numModelReplicas`              | **Required.** The number of replicas for the LLM model.                            | `1`                                       |
| `runtimeEnvironmentPipPackages` | **Required.** A list of pip packages to install in the runtime environment.        | `numpy==1.26.4,vllm==0.9.0,ray==2.46.0`     |
| `huggingfaceModel`              | **Required.** The name of the LLM model from Hugging Face to serve.                | `microsoft/phi-4`                         |
| `tensorParallelSize`            | **Required.** The tensor parallel size for the model.                              | `1`                                       |
| `pipelineParallelSize`          | **Required.** The pipeline parallel size for the model.                            | `1`                                       |
| `placementGroupStrategy`        | **Required.** The placement group strategy for the model.                          | `PACK`                                    |
| `cpuPerActor`                   | **Required.** The number of CPUs to allocate per actor.                            | `16`                                      |
| `gpuPerActor`                   | **Required.** The number of GPUs to allocate per actor.                            | `1`                                       |

### Resource Configuration

**Note:** These values are typically set automatically by exalsius and are only shown here for reference or local testing.

| Parameter          | Description                                       | Default Value | Required |
| ------------------ | ------------------------------------------------- | ------------- | -------- |
| `resources.cpuCores`         | The number of CPU cores for the Ray head.         | `16`          | Yes |
| `resources.memoryGb`         | The amount of memory in GB for the Ray head.      | `32`          | Yes |
| `resources.gpuCount`         | The number of GPUs for the Ray head.              | `1`           | Yes |
| `resources.gpuVendor`        | GPU vendor configuration. Valid values: `"NVIDIA"` or `"AMD"`. | `"NVIDIA"` | No |
| `resources.gpuType`          | GPU type/model.                                   | `"L40"`       | No |
| `resources.gpuMemory`        | GPU memory in gigabytes.                         | `24`          | No |
| `resources.storageGb`        | The size of the persistent volume for your workspace. | `50`          | No |
