<p align="center"><img src="../../docs/img/logo_banner.png" alt="exalsius banner" width="250"></p>

# DiLoCo Training Workspace

This workspace provides a template for running distributed AI training jobs on Kubernetes using DiLoCo (Distributed Low-Communication). 
It is pre-configured to handle distributed setups, resource allocation, and necessary environment variables for training transformers, CNNs, or GNNs on datasets hosted at huggingface.

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

2.  **Install the chart:**
    ```sh
    helm install my-training-job ./diloco-training --set diloco.wandbUserKey=<your-wandb-key> --set diloco.huggingfaceToken=<your-hf-token>
    ```

## Configuration

All configurable options are defined in the `values.yaml` file and can be overridden through `exls` CLI flags or Helm parameters.

### General Configuration

| Parameter             | Description                                       | Default Value                |
| --------------------- | ------------------------------------------------- | ---------------------------- |
| `deploymentNamespace` | The Kubernetes namespace for the deployment.      | `default`                    |
| `deploymentImage`     | The Docker image for the training job.            | `srnbckr/diloco-training:latest` |
| `deploymentName`      | The name of the training job.                     | `diloco-training-job`        |
| `nodes`               | The number of nodes for distributed training.     | `2`                          |

### Resource Configuration

| Parameter          | Description                               | Default Value |
| ------------------ | ----------------------------------------- | ------------- |
| `cpuCores`         | The number of CPU cores to allocate.      | `16`          |
| `memoryGb`         | The amount of memory in GB to allocate.   | `32`          |
| `ephemeralStorageGb` | The amount of storage in GB to allocate.  | `100`         |
| `gpuCount`         | The number of GPUs to allocate.           | `1`           |

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
| `diloco.checkpointPath`        | The path to save checkpoints.                                            | `checkpoint.pth`               |
| `diloco.checkpointInterval`    | The interval (in steps) for saving checkpoints.                          | `512`                          |
| `diloco.device`                | The device to use for training.                                          | `cuda`                         |
| `diloco.wandbProjectName`      | The project name for Weights & Biases logging.                           | `diloco`                       |
| `diloco.wandbGroup`            | The group name for Weights & Biases logging.                             | `diloco-gptneo-c4`             |
| `diloco.heterogeneous`         | Whether the training environment is heterogeneous.                       | `false`                        |
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
