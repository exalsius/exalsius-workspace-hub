<p align="center"><img src="../../docs/img/logo_banner.png" alt="exalsius banner" width="250"></p>

# VS Code Development Container Workspace

This workspace provides a Helm chart for deploying a VS Code development container on Kubernetes. 
It is designed to create a remote development environment with VS Code in the browser, complete with configurable resources and persistent storage. This allows you to code, debug, and test your applications from anywhere.

## Quickstart

### Using the exalsius CLI

The recommended way to deploy this workspace is with the `exls` command-line tool. 
You can deploy it with default settings or customize the Docker image and resources.

```sh
exls workspace deploy dev-pod <CLI-parameters>
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
    helm install my-dev-container ./vscode-devcontainer --set deploymentImage="nvcr.io/nvidia/pytorch:25.01-py3"
    ```

## Configuration

All configurable options are defined in the `values.yaml` file and can be overridden through `exls` CLI flags or Helm parameters.

### Deployment Configuration

| Parameter             | Description                                          | Default Value                     |
| --------------------- | ---------------------------------------------------- | --------------------------------- |
| `deploymentName`      | The name of the deployment.                          | `devcontainer`                    |
| `deploymentNamespace` | The Kubernetes namespace for the deployment.         | `default`                         |
| `deploymentImage`     | The Docker image for the development container.      | `nvcr.io/nvidia/pytorch:25.01-py3`  |

### Resource Configuration

| Parameter             | Description                                                        | Default Value |
| --------------------- | ------------------------------------------------------------------ | ------------- |
| `cpuCores`            | The number of CPU cores to allocate.                               | `16`          |
| `memoryGb`            | The amount of memory in GB to allocate.                            | `32`          |
| `storageGb`           | The size of the persistent volume for your workspace.              | `50`          |
| `gpuCount`            | The number of GPUs to allocate.                                    | `1`           |
| `podEphemeralStorageGb` | The amount of ephemeral storage in GB for the pod.                 | `50`          |
| `podShmSizeGb`        | The size of shared memory (`/dev/shm`) in GB for the pod.          | `8`           |
