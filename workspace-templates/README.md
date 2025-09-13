<p align="left"><img src="./docs/img/logo_banner.png" alt="exalsius banner" width="250"></p>

# exalsius Workspace Hub

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

A collection of Helm chart templates for deploying containerized AI/ML development and service environments on Kubernetes.

## Features

- Pre-configured Helm charts for rapid deployment of services.
- Templates available for:
  - `vscode-devcontainer`: VS Code development container.
  - `jupyter-notebook`: Jupyter Notebook environment.
  - `ray-llm-service`: Ray-based LLM service.
  - `diloco-training`: Distributed AI training jobs.


## Quickstart

Workspaces can be deployed using the [exalsius CLI](https://github.com/exalsius/exalsius-cli) (`exls`) or Helm.

### Using the exalsius CLI

The recommended way to deploy workspaces is with the `exls` command-line tool.

```sh
exls workspace deploy jupyter --jupyter-password <your-secure-password>
```

Parameters from the `values.yaml` file of each workspace can be set as command-line flags.

### Using Helm

You can also deploy workspaces directly using Helm.

1.  **Clone the repository:**
    ```sh
    git clone https://github.com/exalsius/exalsius-workspace-templates.git
    cd exalsius-workspace-templates/workspace-templates
    ```

2.  **Install a chart (e.g., Jupyter Notebook):**
    ```sh
    helm install my-notebook ./jupyter-notebook
    ```

## Configuration

Workspace parameters can be configured either through CLI flags with the [exalsius CLI](https://github.com/exalsius/exalsius-cli) or by overriding values with Helm.
All configurable options are defined in the `values.yaml` file within each chart directory.

### Using the exalsius CLI

When deploying with `exls`, parameters from the `values.yaml` file are mapped to command-line flags. For example, to set the Jupyter password:

```sh
exls workspace deploy jupyter --jupyter-password <your-secure-password>  --docker_image "tensorflow/tensorflow:2.18.0-gpu-jupyter" --gpu_count 4
```

### Using Helm

When using Helm, you can override parameters with the `--set` flag:

```sh
helm install my-notebook ./jupyter-notebook --set notebookPassword=your-super-secret-password
```

## Project Layout

```
workspace-templates/
├── diloco-training/
│   ├── Chart.yaml
│   ├── templates/
│   └── values.yaml
├── jupyter-notebook/
│   ├── Chart.yaml
│   ├── templates/
│   └── values.yaml
├── ray-llm-service/
│   ├── Chart.yaml
│   ├── templates/
│   └── values.yaml
├── test-workspace/
│   ├── Chart.yaml
│   ├── templates/
│   └── values.yaml
└── vscode-devcontainer/
    ├── Chart.yaml
    ├── templates/
    └── values.yaml
```

## Contributing

Contributions are welcome. 
Add your own workspaces that can be deployed via `exls` or `helm`.
Please open an issue to discuss your ideas and submit a pull request with your changes.

## License

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.

