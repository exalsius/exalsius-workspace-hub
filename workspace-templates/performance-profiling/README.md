<p align="center"><img src="../../docs/img/logo_banner.png" alt="exalsius banner" width="250"></p>

# Performance Profiling Workspace

This workspace provides a Helm chart for deploying a performance profiling job on Kubernetes.
It is designed to benchmark and profile various language model configurations, measuring throughput, memory usage, and training performance across different hyperparameters, optimizers, and model architectures.
A single job is scheduled and managed with the [Volcano](https://volcano.sh/en/) batch scheduling system.

## Quickstart

### Using the exalsius CLI

In theory, the ideal way to deploy this workspace is with the `exls` command-line tool.
However, as of now, this workspace template has not yet been implemented.
You may use the regular exalsius API, or refer to the next step.

### Using Helm

You can also deploy the workspace directly using Helm.

1.  **Clone the repository:**
    ```sh
    git clone https://github.com/exalsius/exalsius-workspace-hub.git
    cd exalsius-workspace-templates/workspace-templates
    ```

2.  **Install the chart:**
    ```sh
    helm install my-profiling-job ./performance-profiling
    ```

## Configuration

All configurable options are defined in the `values.yaml` file and can be overridden through Helm parameters.

### Global Configuration (Global helm values)

| Parameter             | Description                                       | Default Value                |
| --------------------- | ------------------------------------------------- | ---------------------------- |
| `deploymentName`      | The name of the profiling job.                    | `performance-profiling-job`  |

### General Configuration

| Parameter             | Description                                       | Default Value                |
| --------------------- | ------------------------------------------------- | ---------------------------- |
| `deploymentNamespace` | The Kubernetes namespace for the deployment.      | `default`                    |
| `deploymentImage`     | The Docker image for the profiling job.           | `ghcr.io/exalsius/exalsius-performance-modeling:dev` |
| `nodes`               | The number of nodes for distributed profiling.    | `1`                          |

### Resource Configuration

| Parameter          | Description                               | Default Value |
| ------------------ | ----------------------------------------- | ------------- |
| `cpuCores`         | The number of CPU cores to allocate.      | `16`          |
| `memoryGb`         | The amount of memory in GB to allocate.   | `32`          |
| `ephemeralStorageGb` | The amount of ephemeral storage in GB to allocate. | `100`         |
| `gpuCount`         | The number of GPUs to allocate.           | `1`           |

### Profiling Configuration

The profiling configuration is defined in `files/profiling_config.json` and includes:

- **Models**: List of models to profile (e.g., `gpt2`, `meta-llama/Llama-3.2-1B`, `google/gemma-3-1b-it`)
- **Batch Sizes**: Different batch sizes to test (1, 2, 4, 8, 16, 32, 64)
- **Sequence Lengths**: Various sequence lengths (32, 64, 128, 256, 512, 1024, 2048, 4096, 8192)
- **Accumulation Steps**: Gradient accumulation steps to test (1, 4, 8)
- **Optimizers**: Different optimizers to benchmark (adam, adamw, sgd)
- **Training Options**: AMP, DDP, fused operations, LoRA, etc.
- **Number of Steps**: Steps to run for each configuration (default: 30)

### Environment Variables

| Parameter                  | Description                                       | Default Value           |
| -------------------------- | ------------------------------------------------- | ----------------------- |
| `MACHINE_NAME`             | Identifier for the machine running the profile.   | `my-machine`            |
| `CLOUD_PROVIDER`           | The cloud provider for the profiling environment. | `my-cloud-provider`     |
| `S3_BUCKET`                | S3 bucket for storing profiling results (optional, otherwise local storage only).          | `my-s3-bucket`          |
| `S3_KEY`                   | S3 access key.                                    | `my-s3-key`             |
| `S3_SECRET`                | S3 secret key.                                    | `my-s3-secret`          |
| `S3_REGION`                | S3 region.                                        | `my-s3-region`          |
| `HF_TOKEN`                 | Hugging Face token for accessing restricted / private models. | `my-hf-token`           |

These can be configured through the `extraEnvironmentVariables` array in `values.yaml`.
