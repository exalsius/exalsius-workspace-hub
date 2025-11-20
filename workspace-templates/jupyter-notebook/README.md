<p align="center"><img src="../../docs/img/logo_banner.png" alt="exalsius banner" width="250"></p>

# Jupyter Notebook Workspace

This workspace provides a Helm chart for deploying a Jupyter Notebook environment on Kubernetes. 
It is designed for rapid setup of a personal data science and machine learning workspace, complete with configurable resources and persistent storage.

## Quickstart

### Using the exalsius CLI

The recommended way to deploy this workspace is with the `exls` command-line tool. You can deploy it with a secure password for your notebook.

```sh
exls workspace deploy jupyter <CLI parameters>
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
    helm install my-notebook ./jupyter-notebook --set notebookPassword=<your-secure-password>
    ```

## Configuration

All configurable options are defined in the `values.yaml` file and can be overridden through `exls` CLI flags or Helm parameters.

### Global Configuration (Global helm values)

| Parameter             | Description                                       | Default Value                |
| --------------------- | ------------------------------------------------- | ---------------------------- |
| `deploymentName`      | The name of the deployment.                       | `my-notebook`                |

### Deployment Configuration

| Parameter             | Description                                          | Default Value                        |
| --------------------- | ---------------------------------------------------- | ------------------------------------ |
| `deploymentNamespace` | The Kubernetes namespace for the deployment.         | `default`                            |
| `deploymentImage`     | The Docker image for the Jupyter Notebook.           | `jupyter/tensorflow-notebook:latest` |
| `enablePvcDeletion`   | If `true`, the PersistentVolumeClaim will be deleted when the workspace is destroyed. | `false` |
| `notebookPassword`    | **Required.** The password to access the Jupyter Notebook. | `mysecurepassword`                   |

### Resource Configuration

| Parameter          | Description                                           | Default Value |
| ------------------ | ----------------------------------------------------- | ------------- |
| `cpuCores`         | The number of CPU cores to allocate.                  | `16`          |
| `memoryGb`         | The amount of memory in GB to allocate.               | `32`          |
| `storageGb`        | The size of the persistent volume for your workspace. | `50`          |
| `gpuCount`         | The number of GPUs to allocate.                       | `1`           |
| `ephemeralStorageGb` | The amount of ephemeral storage in GB for the pod.    | `50`          |
