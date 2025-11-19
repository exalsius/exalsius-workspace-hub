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

### Global Configuration (Global helm values)

| Parameter             | Description                                       | Default Value                |
| --------------------- | ------------------------------------------------- | ---------------------------- |
| `deploymentName`      | The name of the training job.                     | `diloco-training-job`        |

### General Configuration

| Parameter             | Description                                       | Default Value                |
| --------------------- | ------------------------------------------------- | ---------------------------- |
| `deploymentNamespace` | The Kubernetes namespace for the deployment.      | `default`                    |
| `deploymentImage`     | The Docker image for the training job.            | `ghcr.io/exalsius/diloco-training:dev` |
| `global.deploymentName`      | The name of the training job.                     | `diloco-training-job`        |
| `nodes`               | The number of nodes for distributed training.     | `2`                          |

### Resource Configuration

| Parameter          | Description                               | Default Value |
| ------------------ | ----------------------------------------- | ------------- |
| `cpuCores`         | The number of CPU cores to allocate.      | `16`          |
| `memoryGb`         | The amount of memory in GB to allocate.   | `32`          |
| `ephemeralStorageGb` | The amount of storage in GB to allocate.  | `100`         |
| `gpuCount`         | The number of GPUs to allocate.           | `1`           |

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
| `elastic.minNodes`            | Minimum number of nodes for elastic training                             | `2`                |
| `elastic.maxNodes`            | Maximum number of nodes for elastic training                             | `2`                |
| `elastic.nprocPerNode`        | Number of processes (GPUs) per node                                      | `1`                |
| `elastic.maxRestarts`         | Maximum restarts before job fails                                        | `3`                |
| `etcd.enabled`                | Deploy embedded etcd with the chart                                      | `true`             |
| `etcd.replicaCount`           | Number of etcd replicas (1 for dev, 3+ for prod HA)                     | `3`                |
| `elastic.etcd.externalEndpoint` | External etcd cluster endpoint (if not using embedded)                | `""`               |
| `elastic.etcd.prefix`         | etcd key prefix for job isolation                                        | `/torchelastic`    |
| `elastic.etcd.protocol`       | etcd protocol (http or https)                                            | `http`             |

**Fault Tolerance Benefits:**
- Training continues if any worker fails (as long as min_nodes ≤ active_nodes ≤ max_nodes)
- No single point of failure (unlike c10d where worker-0 failure kills the job)
- Automatic re-rendezvous when nodes join or leave
- Production-ready with 3+ etcd replicas for high availability

**Example Configurations:**

*Development (1 etcd replica):*
```yaml
elastic:
  minNodes: 1
  maxNodes: 2
  etcd:
    enabled: true
    replicas: 1
```

*Production (3 etcd replicas, tolerate 1 node failure):*
```yaml
elastic:
  minNodes: 2
  maxNodes: 3
  etcd:
    enabled: true
    replicas: 3
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
| `diloco.localSteps`            | The number of local steps before communication.                          | `128`                          |
| `diloco.lr`                    | The learning rate for the local optimizer.                               | `4e-4`                         |
| `diloco.outerLr`               | The learning rate for the outer optimizer.                               | `0.7`                          |
| `diloco.warmupSteps`           | The number of warmup steps for the learning rate scheduler.              | `1000`                         |
| `diloco.totalSteps`            | The total number of training steps.                                      | `30000`                        |
| `diloco.perDeviceTrainBatchSize` | The training batch size per device.                                      | `32`                           |
| `diloco.batchSize`             | The total batch size across all devices.                                 | `512`                          |
| `diloco.optimMethod`           | The optimization method to use.                                          | `sgd`                          |
| `diloco.quantization`          | Whether to use quantization.                                             | `false`                        |
| `diloco.asyncCommunication`    | Whether to enable async gradient synchronization.                        | `false`                        |
| `diloco.modelCacheDir`         | Directory path for HuggingFace model cache.                              | `/data/models`                 |
| `diloco.datasetCacheDir`       | Directory path for HuggingFace dataset cache.                            | `/data/datasets`               |
| `diloco.checkpointPath`        | The path to save checkpoints.                                            | `/data/checkpoints/checkpoint.pth` |
| `diloco.checkpointInterval`    | The interval (in steps) for saving checkpoints.                          | `512`                          |
| `diloco.device`                | The device to use for training.                                          | `cuda`                         |
| `diloco.wandbProjectName`      | The project name for Weights & Biases logging.                           | `diloco`                       |
| `diloco.wandbGroup`            | The group name for Weights & Biases logging.                             | `diloco-gptneo-c4`             |
| `diloco.wandbRunId`            | Optional WandB run ID (leave empty for auto-generated).                 | `""`                           |
| `diloco.heterogeneous`         | Whether the training environment is heterogeneous.                       | `false`                        |
| `diloco.minBatchSize`          | Minimum batch size for heterogeneous training.                           | `16`                           |
| `diloco.maxBatchSize`          | Maximum batch size for heterogeneous training.                           | `512`                          |
| `diloco.groupPercVariance`     | Group percentage variance for heterogeneous training.                   | `0.15`                         |
| `diloco.compressionDecay`      | The decay factor for compression.                                        | `0.9`                          |
| `diloco.compressionTopk`       | The top-k value for compression.                                         | `32`                           |
| `diloco.experimentDescription` | A description of the experiment.                                         | `DiLoCo distributed training...` |
| `diloco.experimentTags`        | Tags for the experiment.                                                 | `["diloco", "gpt-neo-x", "c4"]`  |
| `diloco.seed`                  | The random seed for reproducibility.                                     | `42`                           |
| `diloco.wandbLogging`          | Whether to enable Weights & Biases logging.                              | `true`                         |
| `diloco.compileModel`          | Whether to compile the model.                                            | `false`                        |
| `diloco.compileBackend`        | The backend to use for model compilation.                                | `inductor`                     |
| `diloco.compileMode`           | The compilation mode.                                                    | `default`                      |
| `diloco.wandbUserKey`          | **Required.** Your Weights & Biases user key.                            | `XXXXXXXXXXXXXXXXX`            |
| `diloco.huggingfaceToken`      | **Required.** Your Hugging Face token.                                   | `hf_XXXXXXXXXXXXXXXXX`         |
