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

### Global Configuration

**Note:** These values are typically set automatically by exalsius and are only shown here for reference or local testing.

| Parameter             | Description                                       | Default Value                |
| --------------------- | ------------------------------------------------- | ---------------------------- |
| `global.deploymentName`      | **Required.** The name of the deployment.                       | `test-workspace`             |
| `global.deploymentNamespace` | **Required.** The Kubernetes namespace for the deployment.      | `default`                    |

### Deployment Configuration

| Parameter             | Description                                  | Default Value      |
| --------------------- | -------------------------------------------- | ------------------ |
| `deploymentImage`     | **Required.** The Docker image for the container.          | `ubuntu:22.04`     |
| `deploymentNumReplicas` | **Required.** Number of deployment replicas. DO NOT CHANGE THIS PARAMETER. | `1` (constant) |
| `ephemeralStorageGb` | **Required.** The amount of ephemeral storage in GB for the pod. | `10`          |

### Resource Configuration

**Note:** These values are typically set automatically by exalsius and are only shown here for reference or local testing.

| Parameter          | Description                                        | Default Value | Required |
| ------------------ | -------------------------------------------------- | ------------- | -------- |
| `resources.cpuCores`         | The number of CPU cores to allocate.               | `1`           | Yes |
| `resources.memoryGb`         | The amount of memory in GB to allocate.            | `2`           | Yes |
| `resources.gpuCount`         | The number of GPUs to allocate.                    | `0`           | Yes |
| `resources.gpuVendor`        | GPU vendor configuration. Valid values: `"NVIDIA"` or `"AMD"`. | `"NVIDIA"` | No |
| `resources.gpuType`          | GPU type/model.                                    | `"L40"`       | No |
| `resources.gpuMemory`        | GPU memory in gigabytes.                          | `24`          | No |
| `resources.storageGb`        | The size of the persistent volume for your workspace. | `10`          | No |
