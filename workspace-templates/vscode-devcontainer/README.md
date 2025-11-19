<p align="center"><img src="../../docs/img/logo_banner.png" alt="exalsius banner" width="250"></p>

# VS Code Development Container Workspace

This workspace provides a Helm chart for deploying a VS Code development container on Kubernetes. 
It is designed to create a remote development environment with VS Code in the browser, complete with configurable resources and persistent storage. The devpod also exposes SSH access, allowing you to connect using Remote SSH plugins from VS Code, Cursor, or IntelliJ. This allows you to code, debug, and test your applications from anywhere.

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
    helm install my-dev-container ./vscode-devcontainer --set gpuVendor="NVIDIA" --set sshPassword="your-password"
    ```

## Configuration

All configurable options are defined in the `values.yaml` file and can be overridden through `exls` CLI flags or Helm parameters.

### Global Configuration (Global helm values)

| Parameter             | Description                                       | Default Value                |
| --------------------- | ------------------------------------------------- | ---------------------------- |
| `deploymentName`      | The name of the deployment.                       | `devcontainer`               |

### Deployment Configuration

| Parameter             | Description                                          | Default Value                     |
| --------------------- | ---------------------------------------------------- | --------------------------------- |
| `deploymentNamespace` | The Kubernetes namespace for the deployment.         | `default`                         |
| `deploymentImage`     | The Docker image for the development container. If not provided, image will be auto-selected based on `gpuVendor`. | `""` (auto-selected) |
| `gpuVendor`          | The GPU vendor to use. Valid values: `"NVIDIA"` or `"AMD"`. Used for automatic image selection and GPU resource allocation. | `"NVIDIA"` |

### SSH Configuration

| Parameter          | Description                                                        | Default Value |
| ------------------ | ------------------------------------------------------------------ | ------------- |
| `sshPassword`      | Password for SSH authentication.                                   | `"testpassword"` |
| `sshPublicKey`     | SSH public key(s) for key-based authentication. Can contain multiple keys, one per line. | `""` |

### Resource Configuration

| Parameter          | Description                                                        | Default Value |
| ------------------ | ------------------------------------------------------------------ | ------------- |
| `cpuCores`         | The number of CPU cores to allocate.                               | `2`           |
| `memoryGb`         | The amount of memory in GB to allocate.                            | `4`           |
| `storageGb`        | The size of the persistent volume for your workspace.              | `50`          |
| `gpuCount`         | The number of GPUs to allocate.                                    | `1`           |
| `shmSizeGb`        | The size of shared memory (`/dev/shm`) in GB for the pod.          | `8`           |

## Remote SSH Connection

The devpod exposes SSH access on port 22 via a NodePort service, allowing you to connect using Remote SSH plugins from your favorite IDEs.

### Connecting with VS Code / Cursor

1. **Install the Remote - SSH extension** in VS Code or Cursor
2. **Get the connection details:**
   - The service exposes SSH on a NodePort. You can find the node IP and port using:
     ```sh
     kubectl get svc <service-name> -n <namespace> -o jsonpath='{.spec.clusterIP}:{.spec.ports[0].nodePort}'
     ```
   - Or check the service annotations for access information
3. **Add to SSH config** (`~/.ssh/config`):
   ```
   Host devpod
       HostName <node-ip>
       Port <nodeport>
       User root
       PasswordAuthentication yes
   ```
4. **Connect:** Use `Remote-SSH: Connect to Host` and select your devpod host

### Connecting with IntelliJ

1. **Open Settings** → **Build, Execution, Deployment** → **Toolchains** → **SSH Configurations**
2. **Add a new SSH configuration** with:
   - Host: `<node-ip>`
   - Port: `<nodeport>`
   - Username: `root`
   - Authentication: Password or Key (depending on your configuration)
3. **Use the SSH connection** for remote development, deployment, or terminal access

**Note:** The default SSH user is `root`. Use the `sshPassword` value or your configured `sshPublicKey` for authentication.
