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
- **NFS Storage**: For shared storage across compute nodes, install the slinky chart with NFS enabled first
- **OpenLDAP** (required if login nodes are enabled): Install the separate `openldap` chart in the `ldap` namespace before installing this chart
- **MariaDB Operator** (required if `slurm.accounting.enabled=true`): Install the separate `mariadb-operator` chart in the `slurm` namespace before installing this chart

## Installation

### Basic Installation

```bash
# Install with default values
helm install my-slurm-cluster . --namespace slurm --create-namespace

# Install with custom values
helm install my-slurm-cluster . -f my-values.yaml --namespace slurm --create-namespace
```

### Installation with NFS Shared Storage

If you need shared storage across compute nodes (recommended for multi-node clusters):

1. **First, install the slinky chart with NFS enabled**:
   ```bash
   helm install slinky ./slinky-v0.4.1 \
     --namespace slinky \
     --create-namespace \
     --set nfs.enabled=true
   ```

2. **Wait for NFS to be ready**:
   ```bash
   kubectl wait --for=condition=ready pod -l role=nfs-server -n nfs-server
   ```

3. **Then install the slurm chart**:
   ```bash
   helm install my-slurm-cluster . \
     --namespace slurm \
     --create-namespace \
     -f my-values.yaml
   ```

The slurm chart will automatically create PVCs using the `nfs-csi` storage class created by the slinky chart.

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

#### 4. With Login Nodes and LDAP Authentication

**PREREQUISITES:** Install OpenLDAP first:

```bash
# Step 1: Install OpenLDAP (prerequisite)
cd ../openldap
helm dependency update
helm install openldap . -n ldap --create-namespace

# Step 2: Wait for OpenLDAP to be ready
kubectl wait --for=condition=ready pod -l app=openldap-stack-ha -n ldap --timeout=300s

# Step 3: (Optional) Add users and groups
kubectl cp ldif-examples/02-groups.ldif openldap-stack-ha-0:/tmp/ -n ldap
kubectl exec -it openldap-stack-ha-0 -n ldap -- ldapadd -x -D "cn=admin,dc=exalsius,dc=ai" -w "Not@SecurePassw0rd" -f /tmp/02-groups.ldif

# Step 4: Install Slurm with login nodes enabled
cd ../slurm-v25.05
helm install my-slurm-cluster . -f my-values.yaml -n slurm
```

**values.yaml:**

```yaml
slurm:
  loginsets:
    login:
      enabled: true
      replicas: 1
      sssdConf: |
        [domain/ldap]
        ldap_uri = ldap://ldap.ldap.svc.cluster.local
        ldap_search_base = dc=exalsius,dc=ai
        ldap_user_search_base = ou=users,dc=exalsius,dc=ai
        ldap_group_search_base = ou=groups,dc=exalsius,dc=ai
        ldap_default_bind_dn = cn=admin,dc=exalsius,dc=ai
        ldap_default_authtok = Not@SecurePassw0rd
```

#### 5. With Accounting Enabled (MariaDB)

**PREREQUISITE:** Install the MariaDB operator first:

```bash
# Step 1: Install MariaDB operator (prerequisite)
cd ../mariadb-operator
helm dependency update
helm install mariadb-operator . -n slurm --create-namespace

# Step 2: Wait for operator to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=mariadb-operator -n slurm --timeout=300s

# Step 3: Install Slurm with accounting enabled
cd ../slurm-v25.05
helm install my-slurm-cluster . -f my-values.yaml -n slurm
```

**values.yaml:**

```yaml
slurm:
  clusterName: "accounting-cluster"
  accounting:
    enabled: true
    storageConfig:
      host: mariadb.slurm.svc.cluster.local
      port: 3306
      database: slurm_acct_db
      username: slurm
      passwordKeyRef:
        name: mariadb-password
        key: password

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

#### 6. Complete Hackathon Setup (Login + Accounting + GPU)

**PREREQUISITES:** Install both OpenLDAP and MariaDB operator first:

```bash
# Step 1: Install OpenLDAP
cd ../openldap
helm dependency update
helm install openldap . -n ldap --create-namespace
kubectl wait --for=condition=ready pod -l app=openldap-stack-ha -n ldap --timeout=300s

# Step 2: Install MariaDB operator
cd ../mariadb-operator
helm dependency update
helm install mariadb-operator . -n slurm --create-namespace
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=mariadb-operator -n slurm --timeout=300s

# Step 3: Install Slurm with full hackathon configuration
cd ../slurm-v25.05
helm install hackathon-cluster . -f values-hackathon-2nodes-2gpu.yaml -n slurm
```

This setup provides:
- GPU compute nodes (MI300X)
- Login nodes with LDAP authentication
- Slurm accounting with MariaDB
- REST API access
- Shared NFS storage

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

## OpenLDAP Integration

This chart supports OpenLDAP integration for user authentication on Slurm login nodes. When login nodes are enabled:

1. **Install OpenLDAP** as a prerequisite (separate chart in `../openldap`) in the `ldap` namespace
2. **Configure users and groups** using LDIF files before installing Slurm
3. **Login nodes automatically connect** to LDAP for authentication via SSSD

### How It Works

OpenLDAP must be installed as a **prerequisite** in a separate namespace before installing this Slurm chart:

- **OpenLDAP Stack HA**: Installed separately using the `openldap` chart in the `ldap` namespace
- **LDAP Service**: Accessible at `ldap://ldap.ldap.svc.cluster.local`
- **SSSD Configuration**: Automatically configured in login nodes to connect to LDAP

### Installation Steps

1. **Install OpenLDAP first:**

```bash
cd ../openldap
helm dependency update
helm install openldap . -n ldap --create-namespace
```

2. **Wait for OpenLDAP to be ready:**

```bash
kubectl wait --for=condition=ready pod -l app=openldap-stack-ha -n ldap --timeout=300s
```

3. **Add users and groups (optional but recommended):**

```bash
# Copy LDIF files to the pod
kubectl cp ../openldap/ldif-examples/02-groups.ldif openldap-stack-ha-0:/tmp/ -n ldap
kubectl cp ../openldap/ldif-examples/03-testuser.ldif openldap-stack-ha-0:/tmp/ -n ldap

# Add groups
kubectl exec -it openldap-stack-ha-0 -n ldap -- \
  ldapadd -x -D "cn=admin,dc=exalsius,dc=ai" -w "Not@SecurePassw0rd" -f /tmp/02-groups.ldif

# Add test user
kubectl exec -it openldap-stack-ha-0 -n ldap -- \
  ldapadd -x -D "cn=admin,dc=exalsius,dc=ai" -w "Not@SecurePassw0rd" -f /tmp/03-testuser.ldif
```

4. **Install the Slurm chart with login nodes enabled:**

```bash
cd ../slurm-v25.05
helm install my-slurm-cluster . -f values-hackathon-2nodes-2gpu.yaml -n slurm
```

### Troubleshooting LDAP

#### Check OpenLDAP Status

```bash
# Check LDAP pods
kubectl get pods -n ldap

# Check LDAP service
kubectl get svc -n ldap

# Test LDAP connection
kubectl exec -it openldap-stack-ha-0 -n ldap -- \
  ldapsearch -x -D "cn=admin,dc=exalsius,dc=ai" -w "Not@SecurePassw0rd" \
  -b "dc=exalsius,dc=ai"
```

#### Common LDAP Issues

1. **Cannot connect to LDAP from login node**: Verify service name is `ldap` in the `ldap` namespace
2. **Authentication fails**: Check bind DN and password in sssdConf configuration
3. **Users not found**: Verify users exist in LDAP using ldapsearch
4. **Cross-namespace DNS resolution**: Ensure full service DNS name is used: `ldap.ldap.svc.cluster.local`

## MariaDB Operator Integration

This chart supports MariaDB integration for Slurm accounting. When `slurm.accounting.enabled` is set to `true`:

1. **Install the MariaDB operator** as a prerequisite (separate chart in `../mariadb-operator`) in the `slurm` namespace
2. **Create a MariaDB database instance** automatically in the same namespace as your Slurm cluster
3. **Configure the database** with optimized settings for Slurm accounting workloads
4. **Generate secrets** for database authentication automatically

### How It Works

The MariaDB operator must be installed as a **prerequisite** before installing this Slurm chart:

- **MariaDB Operator**: Installed separately using the `mariadb-operator` chart in the `slurm` namespace
- **MariaDB Operator CRDs**: Installed as part of the operator chart
- **MariaDB Instance**: Created automatically by this chart when `slurm.accounting.enabled` is true

### Installation Steps

1. **Install the MariaDB operator first:**

```bash
cd ../mariadb-operator
helm dependency update
helm install mariadb-operator . -n slurm --create-namespace
```

2. **Wait for the operator to be ready:**

```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=mariadb-operator -n slurm --timeout=300s
```

3. **Verify the operator and CRDs:**

```bash
# Check operator deployment
kubectl get deployments -n slurm | grep mariadb-operator

# Verify CRDs are installed
kubectl get crd | grep mariadb
```

4. **Install the Slurm chart with accounting enabled:**

```bash
cd ../slurm-v25.05
helm install my-slurm-cluster . -f values-hackathon-2nodes-2gpu.yaml -n slurm
```

### Configuration

#### Basic Accounting Setup

**PREREQUISITE:** The MariaDB operator must be installed first (see Installation Steps above).

```yaml
slurm:
  accounting:
    enabled: true
    storageConfig:
      host: mariadb.slurm.svc.cluster.local
      port: 3306
      database: slurm_acct_db
      username: slurm
      passwordKeyRef:
        name: mariadb-password
        key: password
```

#### Advanced MariaDB Configuration

**PREREQUISITE:** The MariaDB operator must be installed first (see Installation Steps above).

```yaml
slurm:
  accounting:
    enabled: true
    storageConfig:
      host: mariadb.slurm.svc.cluster.local
      port: 3306
      database: slurm_acct_db
      username: slurm
      passwordKeyRef:
        name: mariadb-password
        key: password

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

If you prefer to use an external MariaDB/MySQL database instead of the operator-managed instance:

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
```

**Note:** When using an external database, you don't need to install the MariaDB operator chart.

### Troubleshooting MariaDB

#### Check MariaDB Operator Status

```bash
# Check if operator is running
kubectl get pods -n slurm -l app.kubernetes.io/name=mariadb-operator

# Check operator logs
kubectl logs -n slurm -l app.kubernetes.io/name=mariadb-operator

# Check MariaDB instance
kubectl get mariadb -n slurm

# Check MariaDB pod logs
kubectl logs -n slurm -l app.kubernetes.io/name=mariadb
```

#### Common Issues

1. **"no matches for kind MariaDB" error**: The MariaDB operator is not installed. Install the `mariadb-operator` chart first as a prerequisite.
2. **MariaDB pod stuck in Pending**: Check storage class and available storage
3. **Connection refused**: Ensure MariaDB service is running and accessible
4. **Authentication failed**: Verify secret names and keys match the configuration
5. **Operator webhook issues**: Ensure the operator has been running for at least 30 seconds and the webhook service has endpoints

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
