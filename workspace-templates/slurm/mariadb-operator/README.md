# MariaDB Operator Chart

This Helm chart installs the MariaDB Operator for Kubernetes, which is required as a prerequisite for running Slurm clusters with accounting enabled.

## Overview

The MariaDB Operator manages MariaDB instances in Kubernetes through Custom Resources (CRs). This chart installs:

- **MariaDB Operator CRDs** - Custom Resource Definitions for MariaDB resources
- **MariaDB Operator** - The operator controller that manages MariaDB instances

## Prerequisites

- Kubernetes 1.20+
- Helm 3.0+
- Sufficient cluster resources for the operator deployment

## Installation

### Install the Operator

Install the operator in your target namespace (e.g., `slurm`):

```bash
# Update Helm dependencies
helm dependency update

# Install the operator
helm install mariadb-operator . -n slurm --create-namespace
```

### Verify Installation

Wait for the operator to be ready:

```bash
# Check operator deployment
kubectl get deployments -n slurm | grep mariadb-operator

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=mariadb-operator -n slurm --timeout=300s

# Verify CRDs are installed
kubectl get crd | grep mariadb
```

You should see output similar to:

```
mariadbs.k8s.mariadb.com
backups.k8s.mariadb.com
restores.k8s.mariadb.com
...
```

## Usage

Once the operator is installed and ready, you can install the Slurm chart with accounting enabled. The Slurm chart will automatically create a MariaDB instance using the operator.

```bash
# Install Slurm with accounting enabled
helm install slurm ../slurm-v25.05 \
  -f ../slurm-v25.05/values-hackathon-2nodes-2gpu.yaml \
  -n slurm
```

## Configuration

### values.yaml

The default `values.yaml` enables both operator components:

```yaml
mariadb-operator-crds:
  enabled: true

mariadb-operator:
  enabled: true
  namespaceOverride: ""  # Empty = same namespace as chart
```

### Custom Configuration

You can pass additional configuration to the operator subchart. See the [official MariaDB Operator documentation](https://github.com/mariadb-operator/mariadb-operator) for available options.

Example with custom resource limits:

```yaml
mariadb-operator:
  enabled: true
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
```

## Uninstallation

To uninstall the operator:

```bash
# First, remove any Slurm installations that use MariaDB
helm uninstall slurm -n slurm

# Wait for MariaDB instances to be cleaned up
kubectl wait --for=delete mariadb --all -n slurm --timeout=300s

# Then uninstall the operator
helm uninstall mariadb-operator -n slurm
```

**Important:** Always remove MariaDB instances before uninstalling the operator, otherwise they may become orphaned resources.

## Troubleshooting

### Operator Pod Not Starting

Check the operator logs:

```bash
kubectl logs -l app.kubernetes.io/name=mariadb-operator -n slurm
```

### CRDs Not Installing

Verify Helm dependencies were updated:

```bash
helm dependency list
```

If missing, run:

```bash
helm dependency update
```

### Webhook Connection Issues

The operator uses a validating webhook. Ensure the webhook service is ready:

```bash
kubectl get service -n slurm | grep webhook
kubectl get endpoints -n slurm | grep webhook
```

## Additional Resources

- [MariaDB Operator Documentation](https://github.com/mariadb-operator/mariadb-operator)
- [MariaDB Operator Helm Chart](https://github.com/mariadb-operator/mariadb-operator/tree/main/deploy/charts/mariadb-operator)
- [Slurm Chart Documentation](../slurm-v25.05/README.md)

