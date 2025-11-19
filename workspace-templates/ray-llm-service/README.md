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

### Deployment Configuration

| Parameter             | Description                                                            | Default Value                   |
| --------------------- | ---------------------------------------------------------------------- | ------------------------------- |
| `global.deploymentName`      | The name of the RayService deployment.                                 | `my-llm-service`                |
| `deploymentNamespace` | The Kubernetes namespace for the deployment.                           | `default`                       |
| `deploymentImage`     | The Docker image for the Ray service.                                  | `rayproject/ray-ml:2.46.0.0e19ea` |
| `huggingfaceToken`    | **Optional.** Your Hugging Face token for accessing private models.    | `""`                            |

### Ray and LLM Configuration

| Parameter                       | Description                                                          | Default Value                             |
| ------------------------------- | -------------------------------------------------------------------- | ----------------------------------------- |
| `numModelReplicas`              | The number of replicas for the LLM model.                            | `1`                                       |
| `runtimeEnvironmentPipPackages` | A list of pip packages to install in the runtime environment.        | `numpy==1.26.4,vllm==0.9.0,ray==2.46.0`     |
| `huggingfaceModel`              | The name of the LLM model from Hugging Face to serve.                | `microsoft/phi-4`                         |
| `tensorParallelSize`            | The tensor parallel size for the model.                              | `1`                                       |
| `pipelineParallelSize`          | The pipeline parallel size for the model.                            | `1`                                       |
| `placementGroupStrategy`        | The placement group strategy for the model.                          | `PACK`                                    |
| `cpuPerActor`                   | The number of CPUs to allocate per actor.                            | `16`                                      |
| `gpuPerActor`                   | The number of GPUs to allocate per actor.                            | `1`                                       |

### Resource Configuration

| Parameter          | Description                                       | Default Value |
| ------------------ | ------------------------------------------------- | ------------- |
| `cpuCores`         | The number of CPU cores for the Ray head.         | `16`          |
| `memoryGb`         | The amount of memory in GB for the Ray head.      | `32`          |
| `gpuCount`         | The number of GPUs for the Ray head.              | `1`           |
| `ephemeralStorageGb` | The amount of ephemeral storage in GB for the pod. | `50`          |
