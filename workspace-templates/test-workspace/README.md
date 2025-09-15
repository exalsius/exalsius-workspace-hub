<p align="center"><img src="../../docs/img/logo_banner.png" alt="exalsius banner" width="250"></p>

# Test Workspace

This workspace provides a minimal Helm chart for deploying a basic container on Kubernetes. 
It is primarily intended for end-to-end testing of the workspace deployment pipeline and should not be used for production workloads.

## Quickstart

You can also deploy the workspace directly using Helm.

1.  **Clone the repository:**
    ```sh
    git clone https://github.com/exalsius/exalsius-workspace-hub.git
    cd exalsius-workspace-templates/workspace-templates
    ```

2.  **Install the chart:**
    ```sh
    helm install my-test-workspace ./test-workspace
    ```

## Configuration

All configurable options are defined in the `values.yaml` file and can be overridden through `exls` CLI flags or Helm parameters.

### Deployment Configuration

| Parameter             | Description                                  | Default Value      |
| --------------------- | -------------------------------------------- | ------------------ |
| `deploymentName`      | The name of the deployment.                  | `test-workspace`   |
| `deploymentNamespace` | The Kubernetes namespace for the deployment. | `default`          |
| `deploymentImage`     | The Docker image for the container.          | `ubuntu:22.04`     |

### Resource Configuration

| Parameter          | Description                                        | Default Value |
| ------------------ | -------------------------------------------------- | ------------- |
| `cpuCores`         | The number of CPU cores to allocate.               | `1`           |
| `memoryGb`         | The amount of memory in GB to allocate.            | `2`           |
| `gpuCount`         | The number of GPUs to allocate.                    | `0`           |
| `ephemeralStorageGb` | The amount of ephemeral storage in GB for the pod. | `10`          |
