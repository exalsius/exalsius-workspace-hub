# Ray-LLM Service

A helm-based template for a RayService deployment that serves a specified LLM.

## Prerequisites

- A running Kubernetes cluster.
- The [KubeRay operator](https://github.com/ray-project/kuberay) installed in your cluster.

## Installation

To install the chart, you can use the following command:

```bash
helm install <release-name> . --namespace <namespace>
```

## Configuration

The following table lists the configurable parameters of the Ray-LLM Service chart. For default values, please refer to the `values.yaml` file.

| Parameter                           | Description                                                                  |
|-------------------------------------|------------------------------------------------------------------------------|
| `deploymentNumReplicas`             | Number of replicas for the deployment. **Do not change this value.**           |
| `deploymentName`                    | Name of the deployment.                                                      |
| `deploymentNamespace`               | Namespace for the deployment.                                                |
| `deploymentImage`                   | Docker image for the Ray service.                                            |
| `huggingFaceToken`                  | Optional Hugging Face token for accessing private models.                    |
| `numModelReplicas`                  | Number of replicas for the LLM model.                                        |
| `runtimeEnvironmentPipPackages`     | List of pip packages to install in the runtime environment.                  |
| `llmModelName`                      | Name of the LLM model to serve.                                              |
| `tensorParallelSize`                | Tensor parallel size for the model.                                          |
| `pipelineParallelSize`              | Pipeline parallel size for the model.                                        |
| `placementGroupStrategy`            | Placement group strategy for the model.                                      |
| `cpuPerActor`                       | Number of CPUs per actor.                                                    |
| `gpuPerActor`                       | Number of GPUs per actor.                                                    |
| `cpuCores`                          | Number of CPU cores for the Ray head.                                        |
| `memoryGb`                          | Memory in GB for the Ray head.                                               |
| `storageGb`                         | Ephemeral storage in GB for the Ray head.                                    |
| `gpuCount`                          | Number of GPUs for the Ray head.                                             |

## Deployment

This chart deploys the following Kubernetes resources:

- A `RayService` which manages the Ray cluster and the LLM deployment. **Note:** This chart deploys a single-node Ray cluster, meaning only a head pod is created and no worker pods.
- Two `Service` manifests to expose the LLM via NodePort(s): Once for the dashboard, and once for the serve endpoint.
- A `ConfigMap` to store the runtime environment configuration.
- A `Secret` to store the Hugging Face token, if provided.

## Accessing the Service

Once the service is deployed, you can access the LLM by using one of the provided NodePort services. You will need to lookup the ports that have been automatically used.
