<p align="center"><img src="../../docs/img/logo_banner.png" alt="exalsius banner" width="250"></p>

# DiLoCo Training Workspace

This workspace provides a template for running fault-tolerant distributed AI training jobs on Kubernetes using DiLoCo (Distributed Low-Communication) with **PyTorch Elastic** and **etcd rendezvous**. 

It is pre-configured to handle:
- **Fault-tolerant training**: Continues even if worker nodes fail
- **Elastic scaling**: Dynamic node count between min and max nodes
- **Distributed coordination**: etcd-based rendezvous for robust synchronization
- Training transformers, CNNs, or GNNs on datasets hosted at HuggingFace

## Quickstart

### Using the exalsius CLI

The recommended way to deploy this workspace is with the `exls` command-line tool. You can deploy it with default settings or customize it using flags.

```sh
exls workspace deploy diloco <CLI parameters>
```

### Using Helm

You can also deploy the workspace directly using Helm.

1.  **Clone the repository:**
    ```sh
    git clone https://github.com/exalsius/exalsius-workspace-hub.git
    cd exalsius-workspace-templates/workspace-templates
    ```

2.  **Update dependencies** (to fetch etcd subchart):
    ```sh
    cd diloco-training
    helm dependency update
    ```

3.  **Install the chart:**
    ```sh
    helm install my-training-job ./diloco-training \
      --set diloco.wandbUserKey=<your-wandb-key> \
      --set diloco.huggingfaceToken=<your-hf-token>
    ```

## Configuration

All configurable options are defined in the `values.yaml` file and can be overridden through `exls` CLI flags or Helm parameters.

### Global Configuration

**Note:** These values are typically set automatically by exalsius and are only shown here for reference or local testing.

| Parameter             | Description                                       | Default Value                |
| --------------------- | ------------------------------------------------- | ---------------------------- |
| `global.deploymentName`      | **Required.** The name of the training job.                     | `diloco-training-job`        |
| `global.deploymentNamespace` | **Required.** The Kubernetes namespace for the deployment.      | `default`                    |

### General Configuration

| Parameter             | Description                                       | Default Value                |
| --------------------- | ------------------------------------------------- | ---------------------------- |
| `deploymentNumReplicas` | **Required.** Number of deployment replicas. | `1` (constant) |
| `ephemeralStorageGb` | **Required.** The amount of ephemeral storage in GB to allocate.  | `50`         |
| `elastic`            | **Required.** PyTorch Elastic training configuration with etcd rendezvous. | See PyTorch Elastic Configuration below |
| `diloco`             | **Required.** DiLoCo Training Environment Variables. | See DiLoCo Training Parameters below |
| `etcd`               | **Required.** etcd subchart configuration (bitnami/etcd). | See PyTorch Elastic Configuration below |

### Resource Configuration

**Note:** These values are typically set automatically by exalsius and are only shown here for reference or local testing.

| Parameter          | Description                               | Default Value | Required |
| ------------------ | ----------------------------------------- | ------------- | -------- |
| `resources.cpuCores`         | The number of CPU cores to allocate per worker pod.      | `2`          | Yes |
| `resources.memoryGb`         | The amount of memory in GB to allocate per worker pod.   | `8`          | Yes |
| `resources.gpuCount`         | The number of GPUs per node (also determines PyTorch processes per node).           | `1`           | Yes |
| `resources.gpuVendor`        | GPU vendor configuration. Valid values: `"NVIDIA"` or `"AMD"`. | `"NVIDIA"` | No |
| `resources.gpuType`          | GPU type/model.                           | `"A100"`       | No |
| `resources.gpuMemory`        | GPU memory in gigabytes.                 | `80`          | No |
| `resources.storageGb`       | The size of the persistent volume for your workspace. | `20`          | No |

### Persistent Storage Configuration

This chart supports per-pod persistent storage using Volcano's native `volumeClaim` feature. When enabled, each worker pod receives its own isolated persistent volume mounted at `/data` with subdirectories for models, datasets, and checkpoints.

| Parameter                  | Description                                                    | Default Value        |
| -------------------------- | -------------------------------------------------------------- | -------------------- |
| `storage.enabled`          | Enable persistent storage for each worker pod                  | `true`               |
| `storage.sizeGb`           | Storage size in GB per worker pod                              | `100`                |
| `storage.storageClassName` | Kubernetes storage class (empty = cluster default)             | `""`                 |
| `storage.accessMode`       | Volume access mode (ReadWriteOnce for per-pod isolation)       | `ReadWriteOnce`      |
| `diloco.modelCacheDir`     | Directory path for HuggingFace model cache                     | `/data/models`       |
| `diloco.datasetCacheDir`   | Directory path for HuggingFace dataset cache                   | `/data/datasets`     |
| `diloco.checkpointPath`    | Path for training checkpoints                                  | `/data/checkpoints/checkpoint.pth` |

**Storage Architecture:**

Each worker pod gets its own persistent volume with the following structure:

```
/data/
├── models/       (HuggingFace model cache - DILOCO_MODEL_CACHE_DIR)
├── datasets/     (HuggingFace dataset cache - DILOCO_DATASET_CACHE_DIR)
└── checkpoints/  (Training checkpoints - DILOCO_CHECKPOINT_PATH)
```

**Benefits:**
- **Persistence**: Storage survives pod restarts and rescheduling
- **Isolation**: Each worker has its own storage (no sharing conflicts)
- **Performance**: Models and datasets cached locally, reducing download times
- **Checkpointing**: Training state preserved across failures

**Notes:**
- Volcano automatically creates PVCs with names like `{job-name}-worker-0-data`, `{job-name}-worker-1-data`, etc.
- PVCs are not automatically deleted when the job completes (manual cleanup required)
- To disable persistent storage, set `storage.enabled: false` (cache directories will use container ephemeral storage)

### PyTorch Elastic Configuration

| Parameter                     | Description                                                              | Default Value      |
| ----------------------------- | ------------------------------------------------------------------------ | ------------------ |
| `elastic.minNodes`            | Minimum number of nodes for elastic training (total across all GPU types) | `2`                |
| `elastic.maxNodes`            | Maximum number of nodes for elastic training (total across all GPU types) | `3`                |
| `elastic.gpuDistribution`     | GPU distribution policy: `auto`, `prefer-nvidia`, or `prefer-amd`        | `auto`             |
| `elastic.maxRestarts`         | Maximum restarts before job fails                                        | `3`                |
| `etcd.enabled`                | Deploy embedded etcd with the chart                                      | `true`             |
| `etcd.replicaCount`           | Number of etcd replicas (1 for dev, 3+ for prod HA)                     | `1`                |
| `elastic.etcd.externalEndpoint` | External etcd cluster endpoint (if not using embedded)                | `""`               |
| `elastic.etcd.prefix`         | etcd key prefix for job isolation                                        | `/torchelastic`    |
| `elastic.etcd.protocol`       | etcd protocol (http or https)                                            | `http`             |

**Fault Tolerance Benefits:**
- Training continues if any worker fails (as long as min_nodes ≤ active_nodes ≤ max_nodes)
- No single point of failure (unlike c10d where worker-0 failure kills the job)
- Automatic re-rendezvous when nodes join or leave
- Production-ready with 3+ etcd replicas for high availability

### GPU Configuration (Heterogeneous Support)

The chart supports both homogeneous (single GPU type) and heterogeneous (mixed NVIDIA and AMD GPUs) clusters. There are two configuration modes:

#### Simple Mode (Recommended)

Specify total GPU needs and let the chart distribute across available GPU types:

| Parameter                | Description                                                                | Default Value                            |
| ------------------------ | -------------------------------------------------------------------------- | ---------------------------------------- |
| `elastic.minNodes`       | Total minimum nodes needed                                                 | `2`                                      |
| `elastic.maxNodes`       | Total maximum nodes needed                                                 | `3`                                      |
| `elastic.gpuDistribution`| How to distribute: `auto` (split evenly), `prefer-nvidia`, `prefer-amd`   | `auto`                                   |
| `gpu.nvidia.enabled`     | Enable NVIDIA GPU workers                                                  | `true`                                   |
| `gpu.nvidia.image`       | Docker image for NVIDIA workers                                            | `ghcr.io/exalsius/diloco-training:latest-nvidia` |
| `gpu.amd.enabled`        | Enable AMD GPU workers                                                     | `false`                                  |
| `gpu.amd.image`          | Docker image for AMD workers                                               | `ghcr.io/exalsius/diloco-training:latest-rocm`   |

**Example - 5 GPUs, any type:**
```yaml
elastic:
  minNodes: 5
  maxNodes: 5
  gpuDistribution: "auto"  # Splits evenly: 3 NVIDIA max, 2 AMD max
gpu:
  nvidia:
    enabled: true
  amd:
    enabled: true
```

**Example - Prefer NVIDIA, fallback to AMD:**
```yaml
elastic:
  minNodes: 4
  maxNodes: 4
  gpuDistribution: "prefer-nvidia"  # 4 NVIDIA max (min=4), 4 AMD max (min=0)
gpu:
  nvidia:
    enabled: true
  amd:
    enabled: true
```

**Example - NVIDIA only (backward compatible):**
```yaml
elastic:
  minNodes: 2
  maxNodes: 3
gpu:
  nvidia:
    enabled: true
  amd:
    enabled: false
```

#### Advanced Mode

Explicitly control GPU allocation per type:

| Parameter                | Description                                                                | Default Value |
| ------------------------ | -------------------------------------------------------------------------- | ------------- |
| `gpu.nvidia.minNodes`    | Minimum NVIDIA nodes (overrides elastic.minNodes if set)                  | `null`        |
| `gpu.nvidia.maxNodes`    | Maximum NVIDIA nodes (overrides elastic.maxNodes if set)                  | `null`        |
| `gpu.amd.minNodes`       | Minimum AMD nodes (overrides elastic.minNodes if set)                     | `null`        |
| `gpu.amd.maxNodes`       | Maximum AMD nodes (overrides elastic.maxNodes if set)                     | `null`        |

**Example - Explicit heterogeneous allocation:**
```yaml
gpu:
  nvidia:
    enabled: true
    minNodes: 2
    maxNodes: 3
  amd:
    enabled: true
    minNodes: 1
    maxNodes: 2
```
Result: Requires 3 nodes minimum (2 NVIDIA + 1 AMD), up to 5 maximum (3 NVIDIA + 2 AMD)

**Example Configurations:**

*Development (1 etcd replica):*
```yaml
elastic:
  minNodes: 1
  maxNodes: 2
etcd:
  enabled: true
  replicaCount: 1
```

*Production (3 etcd replicas, tolerate 1 node failure):*
```yaml
elastic:
  minNodes: 2
  maxNodes: 3
etcd:
  enabled: true
  replicaCount: 3
```

*Production with External etcd:*
```yaml
elastic:
  minNodes: 2
  maxNodes: 4
  etcd:
    enabled: false
    externalEndpoint: "etcd-cluster.infrastructure.svc.cluster.local:2379"
```

### DiLoCo Training Parameters

These parameters configure the DiLoCo training process and are passed as environment variables to the training container.

| Parameter                      | Description                                                              | Default Value                  |
| ------------------------------ | ------------------------------------------------------------------------ | ------------------------------ |
| `diloco.model`                 | The model to be trained.                                                 | `gpt-neo-x`                    |
| `diloco.dataset`               | The dataset to use for training.                                         | `c4`                           |
| `diloco.localSteps`            | The number of local steps before communication (integer).               | `10`                           |
| `diloco.lr`                    | The learning rate for the local optimizer (number).                      | `4e-4`                         |
| `diloco.outerLr`               | The learning rate for the outer optimizer (number).                     | `0.7`                          |
| `diloco.warmupSteps`           | The number of warmup steps for the learning rate scheduler (integer).    | `500`                          |
| `diloco.totalSteps`            | The total number of training steps (integer).                            | `20`                           |
| `diloco.perDeviceTrainBatchSize` | The training batch size per device (integer).                            | `64`                           |
| `diloco.batchSize`             | The total batch size across all devices (integer).                       | `512`                          |
| `diloco.optimMethod`           | The optimization method to use.                                          | `sgd`                          |
| `diloco.quantization`          | Whether to use quantization (boolean).                                    | `false`                        |
| `diloco.asyncCommunication`    | Whether to enable async gradient synchronization (boolean).            | `false`                        |
| `diloco.modelCacheDir`         | Directory path for HuggingFace model cache.                              | `/data/models`                 |
| `diloco.datasetCacheDir`       | Directory path for HuggingFace dataset cache.                            | `/data/datasets`               |
| `diloco.checkpointPath`        | The path to save checkpoints.                                            | `checkpoint.pth`                |
| `diloco.checkpointInterval`    | The interval (in steps) for saving checkpoints (integer).                | `5`                            |
| `diloco.device`                | The device to use for training.                                          | `cuda`                         |
| `diloco.wandbProjectName`      | The project name for Weights & Biases logging.                           | `diloco-training`              |
| `diloco.wandbGroup`            | The group name for Weights & Biases logging.                             | `diloco-heterogenous`          |
| `diloco.wandbRunId`            | Optional WandB run ID (leave empty for auto-generated).                 | `gpt-neo-x`                    |
| `diloco.heterogeneous`         | Whether the training environment is heterogeneous (boolean).             | `true`                         |
| `diloco.minBatchSize`          | Minimum batch size for heterogeneous training (integer).                 | `32`                           |
| `diloco.maxBatchSize`          | Maximum batch size for heterogeneous training (integer).                 | `512`                          |
| `diloco.groupPercVariance`     | Group percentage variance for heterogeneous training (number).          | `0.15`                         |
| `diloco.compressionDecay`      | The decay factor for compression (number).                               | `0.95`                         |
| `diloco.compressionTopk`       | The top-k value for compression (integer).                                | `32`                           |
| `diloco.experimentDescription` | A description of the experiment.                                         | `DiLoCo distributed training...` |
| `diloco.experimentTags`        | Tags for the experiment.                                                 | `["diloco", "gpt-neo-x", "c4"]`  |
| `diloco.seed`                  | The random seed for reproducibility (integer).                           | `42`                           |
| `diloco.wandbLogging`          | Whether to enable Weights & Biases logging (boolean).                    | `true`                         |
| `diloco.compileModel`          | Whether to compile the model (boolean).                                  | `false`                        |
| `diloco.compileBackend`        | The backend to use for model compilation.                                | `inductor`                     |
| `diloco.compileMode`           | The compilation mode.                                                    | `default`                      |
| `diloco.hfUpload`              | Whether to enable HuggingFace model upload (boolean).                    | `true`                         |
| `diloco.trainedModelHfName`    | HuggingFace model name for upload.                                       | `test-model`                   |
| `diloco.wandbUserKey`          | **Required.** Your Weights & Biases user key.                            | `XXXXXXXXXXXXXXXXX`            |
| `diloco.huggingfaceToken`      | **Required.** Your Hugging Face token.                                   | `hf_XXXXXXXXXXXXXXXXX`         |
