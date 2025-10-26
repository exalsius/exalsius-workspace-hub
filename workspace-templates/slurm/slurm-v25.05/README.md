# Slurm Umbrella Chart

A Helm umbrella chart that provides a simplified interface for deploying Slurm clusters on Kubernetes using the [slinkyproject/slurm](https://github.com/SlinkyProject/slurm) chart.

## Overview

This chart wraps the official slinkyproject/slurm Helm chart (v0.4.1) and provides:

- **Sensible defaults** for common Slurm cluster configurations
- **Simplified configuration** with only the most commonly customized values exposed
- **Full flexibility** - users can still override any upstream chart value
- **Easy deployment** with minimal configuration required

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- A storage class for persistent volumes (controller state persistence)
- Sufficient cluster resources for your compute nodes

## Installation

### Basic Installation

```bash
# Install with default values
helm install my-slurm-cluster . --namespace slurm --create-namespace

# Install with custom values
helm install my-slurm-cluster . -f my-values.yaml --namespace slurm --create-namespace
```

### Using the ServiceTemplate

If you're using this chart through the K0rdent ServiceTemplate system:

```yaml
apiVersion: k0rdent.mirantis.com/v1beta1
kind: ServiceTemplate
metadata:
  name: my-slurm-cluster
  namespace: kcm-system
spec:
  helm:
    chartSpec:
      chart: workspace-templates/slurm/slurm-v25.05
      version: "0.1.0"
      sourceRef:
        kind: GitRepository
        name: exalsius-workspace-hub
```

## Configuration

### Basic Configuration

The `values.yaml` file exposes the most commonly customized settings:

```yaml
slurm:
  # Cluster identification
  clusterName: "my-slurm-cluster"
  
  # Controller persistence
  controller:
    persistence:
      enabled: true
      storageClassName: ""  # Use default storage class
      size: 4Gi
  
  # Compute nodes
  nodesets:
    default:
      enabled: true
      replicas: 2
      slurmd:
        resources:
          limits:
            cpu: "4"
            memory: "8Gi"
  
  # Partitions
  partitions:
    main:
      enabled: true
      nodesets: ["ALL"]
      configMap:
        State: UP
        Default: "YES"
```

### Common Scenarios

#### 1. Single Node Cluster

```yaml
slurm:
  clusterName: "single-node-cluster"
  nodesets:
    default:
      enabled: true
      replicas: 1
      slurmd:
        resources:
          limits:
            cpu: "2"
            memory: "4Gi"
  partitions:
    main:
      enabled: true
      nodesets: ["ALL"]
      configMap:
        State: UP
        Default: "YES"
        MaxTime: "24:00:00"
```

#### 2. GPU-Enabled Cluster

```yaml
slurm:
  clusterName: "gpu-cluster"
  nodesets:
    gpu-nodes:
      enabled: true
      replicas: 2
      slurmd:
        image:
          repository: ghcr.io/exalsius/slurmd
          tag: 25.05.3-ubuntu24.04-rocm
        resources:
          limits:
            cpu: "16"
            memory: "132Gi"
            amd.com/gpu: 1
      podSpec:
        nodeSelector:
          amd.com/gpu: "true"
        tolerations:
          - key: amd.com/gpu
            effect: NoSchedule
  partitions:
    gpu:
      enabled: true
      nodesets: ["gpu-nodes"]
      configMap:
        State: UP
        MaxTime: UNLIMITED
```

#### 3. High Availability Setup

```yaml
slurm:
  clusterName: "ha-cluster"
  controller:
    persistence:
      enabled: true
      storageClassName: "fast-ssd"
      size: 10Gi
    podSpec:
      nodeSelector:
        node-role.kubernetes.io/control-plane: ""
  nodesets:
    compute:
      enabled: true
      replicas: 3
      updateStrategy:
        type: RollingUpdate
        rollingUpdate:
          maxUnavailable: 1
```

#### 4. With Accounting Enabled (MariaDB Operator)

```yaml
slurm:
  clusterName: "accounting-cluster"
  accounting:
    enabled: true
    storageConfig:
      host: mariadb
      port: 3306
      database: slurm_acct_db
      username: slurm
      passwordKeyRef:
        name: mariadb-password
        key: password

# MariaDB operator will be automatically installed when accounting is enabled
# The MariaDB instance will be created in the same namespace as the Slurm cluster
mariadb:
  storage:
    size: 2Gi
    storageClassName: "fast-ssd"
  resources:
    limits:
      cpu: "2000m"
      memory: "4Gi"
```

#### 5. With Login Nodes

```yaml
slurm:
  clusterName: "login-cluster"
  loginsets:
    login:
      enabled: true
      replicas: 2
      login:
        resources:
          limits:
            cpu: "2"
            memory: "4Gi"
      podSpec:
        nodeSelector:
          node-role.kubernetes.io/login: ""
      service:
        spec:
          type: LoadBalancer
```

## Advanced Configuration

### Overriding Upstream Values

You can override ANY value from the upstream slinkyproject/slurm chart by adding it to the `slurm:` block in your values file:

```yaml
slurm:
  # Your custom values here
  clusterName: "my-cluster"
  
  # Override upstream values
  controller:
    slurmctld:
      image:
        repository: my-registry.com/slurmctld
        tag: custom-tag
    extraConf: |-
      SchedulerParameters=batch_sched_delay=30
      DefMemPerCPU=2
      MaxJobCount=1000
  
  # Add custom config files
  configFiles:
    gres.conf: |
      AutoDetect=nvidia
      Name=gpu Type=gpu File=/dev/nvidia0
    cgroup.conf: |
      CgroupPlugin=autodetect
      ConstrainCores=yes
      ConstrainRAMSpace=yes
```

### Using values-full.yaml

For complex configurations, you can use the `values-full.yaml` file as a starting point:

```bash
# Copy the full values file
cp values-full.yaml my-custom-values.yaml

# Edit to your needs
vim my-custom-values.yaml

# Install with your custom values
helm install my-slurm-cluster . -f my-custom-values.yaml
```

The `values-full.yaml` file contains all available configuration options with detailed comments and examples.

## MariaDB Operator Integration

This chart includes MariaDB operator integration for Slurm accounting. When `slurm.accounting.enabled` is set to `true`, you can:

1. **Install the MariaDB operator** in the `mariadb` namespace by enabling the dependencies
2. **Create a MariaDB database instance** in the same namespace as your Slurm cluster
3. **Configure the database** with optimized settings for Slurm accounting workloads
4. **Generate secrets** for database authentication automatically

### How It Works

The integration uses Helm chart dependencies to manage the MariaDB operator lifecycle:

- **MariaDB Operator CRDs**: Installed when `mariadb-operator-crds.enabled` is true
- **MariaDB Operator**: Installed when `mariadb-operator.enabled` is true  
- **MariaDB Instance**: Created via a custom resource when `slurm.accounting.enabled` is true

### Configuration

#### Basic Accounting Setup

```yaml
slurm:
  accounting:
    enabled: true
    storageConfig:
      host: mariadb
      port: 3306
      database: slurm_acct_db
      username: slurm
      passwordKeyRef:
        name: mariadb-password
        key: password

# Enable MariaDB operator dependencies
mariadb-operator-crds:
  enabled: true
mariadb-operator:
  enabled: true
```

#### Advanced MariaDB Configuration

```yaml
slurm:
  accounting:
    enabled: true
    storageConfig:
      host: mariadb
      port: 3306
      database: slurm_acct_db
      username: slurm
      passwordKeyRef:
        name: mariadb-password
        key: password

# Enable MariaDB operator dependencies
mariadb-operator-crds:
  enabled: true
mariadb-operator:
  enabled: true

# Customize MariaDB instance
mariadb:
  storage:
    size: 10Gi
    storageClassName: "fast-ssd"
  config:
    innodbBufferPoolSize: "8G"
    innodbLogFileSize: "2G"
  resources:
    limits:
      cpu: "4000m"
      memory: "8Gi"
```

#### External Database

If you prefer to use an external MariaDB/MySQL database:

```yaml
slurm:
  accounting:
    enabled: true
    storageConfig:
      host: external-db.example.com
      port: 3306
      database: slurm_acct_db
      username: slurm
      passwordKeyRef:
        name: external-db-credentials
        key: password

# Disable MariaDB operator
mariadb-operator-crds:
  enabled: false
mariadb-operator:
  enabled: false
```

### Troubleshooting MariaDB

#### Check MariaDB Operator Status

```bash
# Check if operator is running
kubectl get pods -n mariadb

# Check MariaDB instance
kubectl get mariadb -n slurm

# Check MariaDB pod logs
kubectl logs -n slurm -l app.kubernetes.io/name=mariadb
```

#### Common Issues

1. **MariaDB pod stuck in Pending**: Check storage class and available storage
2. **Connection refused**: Ensure MariaDB service is running and accessible
3. **Authentication failed**: Verify secret names and keys match the configuration

#### Database Management

```bash
# Connect to MariaDB instance
kubectl exec -it -n slurm deployment/mariadb -- mariadb -u slurm -p slurm_acct_db

# Check Slurm accounting tables
kubectl exec -it -n slurm deployment/mariadb -- mariadb -u slurm -p slurm_acct_db -e "SHOW TABLES;"
```

## Monitoring

### Prometheus Metrics

Enable Prometheus metrics collection:

```yaml
slurm:
  slurm-exporter:
    enabled: true
    exporter:
      enabled: true
      secretName: "slurm-token-exporter"
```

### Logging

Configure logging levels and outputs:

```yaml
slurm:
  controller:
    slurmctld:
      args: ["-vvv"]  # Enable debug logging
  nodesets:
    default:
      slurmd:
        args: ["-vvv"]  # Enable debug logging
```

## Troubleshooting

### Common Issues

#### 1. Controller Pod Stuck in Pending

**Problem**: Controller pod cannot be scheduled.

**Solution**: Check node selectors and tolerations:

```yaml
slurm:
  controller:
    podSpec:
      nodeSelector: {}  # Remove restrictive selectors
      tolerations: []   # Add required tolerations
```

#### 2. Compute Nodes Not Joining Cluster

**Problem**: Slurmd pods start but don't register with controller.

**Solution**: Check network connectivity and authentication:

```yaml
slurm:
  # Ensure proper cluster name
  clusterName: "my-cluster"
  
  # Check authentication keys
  slurmKeyRef: {}  # Let chart generate keys
```

#### 3. Storage Issues

**Problem**: Persistent volume claims fail to bind.

**Solution**: Verify storage class and resources:

```yaml
slurm:
  controller:
    persistence:
      storageClassName: "fast-ssd"  # Use available storage class
      resources:
        requests:
          storage: 4Gi  # Ensure sufficient size
```

#### 4. Resource Limits Too Low

**Problem**: Jobs fail due to insufficient resources.

**Solution**: Adjust resource limits:

```yaml
slurm:
  nodesets:
    default:
      slurmd:
        resources:
          limits:
            cpu: "8"      # Increase CPU
            memory: "16Gi" # Increase memory
```

### Debugging Commands

```bash
# Check pod status
kubectl get pods -n slurm

# View controller logs
kubectl logs -n slurm -l app.kubernetes.io/name=slurm,app.kubernetes.io/component=controller

# View compute node logs
kubectl logs -n slurm -l app.kubernetes.io/name=slurm,app.kubernetes.io/component=slurmd

# Check Slurm configuration
kubectl exec -n slurm <controller-pod> -- cat /etc/slurm/slurm.conf

# Test Slurm commands
kubectl exec -n slurm <controller-pod> -- sinfo
kubectl exec -n slurm <controller-pod> -- squeue
```

## Upstream Documentation

This chart is based on the [slinkyproject/slurm](https://github.com/SlinkyProject/slurm) Helm chart. For detailed information about:

- **Chart configuration**: [slinkyproject/slurm values.yaml](https://github.com/SlinkyProject/slurm/blob/main/helm/slurm/values.yaml)
- **Slurm configuration**: [Slurm Configuration Guide](https://slurm.schedmd.com/configuration.html)
- **Kubernetes integration**: [SlinkyProject Documentation](https://github.com/SlinkyProject/slurm)

## Contributing

To contribute to this umbrella chart:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with various configurations
5. Submit a pull request

## License

This chart is licensed under the same terms as the upstream slinkyproject/slurm chart.
