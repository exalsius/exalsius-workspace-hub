<p align="center"><img src="../../docs/img/logo_banner.png" alt="exalsius banner" width="250"></p>

# Marimo Workspace

This workspace provides a Helm chart for deploying a [Marimo](https://marimo.io/) notebook environment on Kubernetes.  
It is designed for rapid setup of a personal or collaborative data science and machine learning workspace, with configurable resources and persistent storage.

## Quickstart

### Using the exalsius CLI

The recommended way to deploy this workspace is with the `exls` command-line tool:

```sh
exls workspace deploy marimo <CLI parameters>
````

### Using Helm

You can also deploy the workspace directly using Helm.

1. **Clone the repository:**

   ```sh
   git clone https://github.com/exalsius/exalsius-workspace-hub.git
   cd exalsius-workspace-hub/workspace-templates
   ```

2. **Install the chart:**

   ```sh
   helm install my-marimo ./marimo
   ```

## Configuration

All configurable options are defined in the `values.yaml` file and can be overridden through `exls` CLI flags or Helm parameters.

### Deployment Configuration

| Parameter             | Description                                                                           | Default Value                    |
| --------------------- | ------------------------------------------------------------------------------------- | -------------------------------- |
| `deploymentName`      | The name of the deployment.                                                           | `my-marimo`                      |
| `deploymentNamespace` | The Kubernetes namespace for the deployment.                                          | `default`                        |
| `deploymentImage`     | The Docker image for the Marimo notebook.                                             | `ghcr.io/marimo-team/marimo:latest-data` |
| `enablePvcDeletion`   | If `true`, the PersistentVolumeClaim will be deleted when the workspace is destroyed. | `false`                          |
| `tokenPassword`    | **Required.** The password to access the Marimo webinterface. | `mysecurepassword`                   |

### Resource Configuration

| Parameter            | Description                                           | Default Value |
| -------------------- | ----------------------------------------------------- | ------------- |
| `cpuCores`           | The number of CPU cores to allocate.                  | `8`           |
| `memoryGb`           | The amount of memory in GB to allocate.               | `16`          |
| `storageGb`          | The size of the persistent volume for your workspace. | `20`          |
| `gpuCount`           | The number of GPUs to allocate.                       | `0`           |
| `ephemeralStorageGb` | The amount of ephemeral storage in GB for the pod.    | `20`          |
