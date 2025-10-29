# Slinky Chart

A Helm chart for Slinky with Slurm operator dependencies and optional NFS server deployment.

## Overview

This chart provides:
- **Slurm Operator**: Core Slurm operator and CRDs
- **NFS Server**: Optional NFS server with configurable node placement
- **CSI Driver**: NFS CSI driver for dynamic storage provisioning
- **Storage Class**: Automatic creation of NFS storage class

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- A storage class for NFS server persistent volumes (when NFS is enabled)

## Installation

### Basic Installation (Slurm Operator Only)

```bash
# Install with default values (only slurm operator)
helm install slinky ./slinky-v0.4.1 --namespace slinky --create-namespace
```

### With NFS Server

```bash
# Install with NFS server enabled
helm install slinky ./slinky-v0.4.1 \
  --namespace slinky \
  --create-namespace \
  --set nfs.enabled=true
```

### With NFS Server on Specific Node

```bash
# Pin NFS server to specific node
helm install slinky ./slinky-v0.4.1 \
  --namespace slinky \
  --create-namespace \
  --set nfs.enabled=true \
  --set nfs.server.nodeSelector."kubernetes\.io/hostname"=storage-node-1
```

### With NFS Server on Labeled Nodes

```bash
# Schedule NFS server on nodes with specific label
helm install slinky ./slinky-v0.4.1 \
  --namespace slinky \
  --create-namespace \
  --set nfs.enabled=true \
  --set nfs.server.nodeSelector.storage-node=true
```

## Configuration

### NFS Server Configuration

The NFS server can be configured with the following options:

```yaml
nfs:
  # -- Enable NFS server and CSI driver deployment
  enabled: false
  
  # -- NFS server configuration
  server:
    # -- Namespace for NFS server
    namespace: nfs-server
    # -- NFS server image configuration
    image:
      repository: itsthenetwork/nfs-server-alpine
      tag: latest
    # -- Storage configuration for NFS server
    storage:
      # -- Size of the persistent volume for NFS server
      size: 500Gi
      # -- Storage class for the persistent volume (underlying storage)
      storageClassName: openebs-hostpath
    # -- Resource limits and requests for NFS server
    resources:
      limits:
        cpu: "500m"
        memory: "512Mi"
      requests:
        cpu: "100m"
        memory: "128Mi"
    # -- Node selector for NFS server pod placement
    # If empty {}, NFS server will be scheduled on any available node
    nodeSelector: {}
      # Example to pin to specific node:
      # kubernetes.io/hostname: node-1
      # Or to schedule on nodes with specific label:
      # storage-node: "true"
    # -- Tolerations for NFS server pod
    tolerations: []
      # Example:
      # - key: "node-role"
      #   operator: "Equal"
      #   value: "storage"
      #   effect: "NoSchedule"
```

### CSI Driver Configuration

The NFS CSI driver is automatically configured when NFS is enabled:

```yaml
csi-driver-nfs:
  # -- Storage class configuration
  storageClass:
    # -- Create storage class
    create: true
    # -- Name of the storage class
    name: nfs-csi
    # -- Storage class parameters
    parameters:
      server: nfs-server.nfs-server.svc.cluster.local
      share: /
    # -- Reclaim policy
    reclaimPolicy: Delete
    # -- Volume binding mode
    volumeBindingMode: Immediate
    # -- Mount options
    mountOptions:
      - nfsvers=4.1
  
  # -- Kubelet directory (specific to k0s)
  kubeletDir: /var/lib/k0s/kubelet
```

## Node Placement Examples

### Pin to Specific Node

```yaml
nfs:
  enabled: true
  server:
    nodeSelector:
      kubernetes.io/hostname: storage-node-1
```

### Schedule on Labeled Nodes

```yaml
nfs:
  enabled: true
  server:
    nodeSelector:
      storage-node: "true"
    tolerations:
      - key: "node-role"
        operator: "Equal"
        value: "storage"
        effect: "NoSchedule"
```

### Any Node (Default)

```yaml
nfs:
  enabled: true
  server:
    nodeSelector: {}
    tolerations: []
```

## Usage with Slurm Chart

This chart is designed to work with the slurm chart. The typical deployment order is:

1. **Install Slinky chart** (with NFS if needed):
   ```bash
   helm install slinky ./slinky-v0.4.1 \
     --namespace slinky \
     --create-namespace \
     --set nfs.enabled=true
   ```

2. **Wait for NFS to be ready** (if NFS is enabled):
   ```bash
   kubectl wait --for=condition=ready pod -l role=nfs-server -n nfs-server
   ```

3. **Install Slurm chart**:
   ```bash
   helm install hackathon-cluster ./slurm-v25.05 \
     --namespace slurm \
     --create-namespace \
     -f values-hackathon-3nodes.yaml
   ```

## Verification

### Check NFS Server Status

```bash
# Check if NFS server is running
kubectl get pods -n nfs-server

# Check NFS server pod placement
kubectl get pod -n nfs-server -o wide

# Check NFS server logs
kubectl logs -n nfs-server deployment/nfs-server
```

### Check Storage Class

```bash
# Verify NFS storage class exists
kubectl get storageclass nfs-csi

# Check storage class details
kubectl describe storageclass nfs-csi
```

### Test NFS Connectivity

```bash
# Test NFS server connectivity
kubectl run nfs-test --image=busybox --rm -it --restart=Never -- sh -c "nc -z nfs-server.nfs-server.svc.cluster.local 2049 && echo 'NFS server is reachable'"
```

## Troubleshooting

### NFS Server Not Starting

1. **Check node selector**: Ensure the specified node exists and has the required labels
2. **Check tolerations**: Verify tolerations match node taints
3. **Check resources**: Ensure nodes have sufficient CPU/memory
4. **Check storage**: Verify the underlying storage class is available

### Storage Class Not Created

1. **Check CSI driver**: Verify the CSI driver pods are running
2. **Check NFS server**: Ensure NFS server is running and accessible
3. **Check logs**: Review CSI driver logs for errors

### PVCs Not Binding

1. **Check storage class**: Verify `nfs-csi` storage class exists
2. **Check NFS server**: Ensure NFS server is running and accessible
3. **Check network**: Verify network connectivity between nodes and NFS server

## Cleanup

To remove the chart:

```bash
# Delete the Helm release
helm uninstall slinky -n slinky

# Delete the namespace (optional)
kubectl delete namespace slinky

# If NFS was enabled, also delete the NFS namespace
kubectl delete namespace nfs-server
```

## Support

For issues with this chart:

1. Check the troubleshooting section above
2. Review NFS server logs: `kubectl logs -n nfs-server deployment/nfs-server`
3. Check CSI driver logs: `kubectl logs -n kube-system -l app=csi-nfs-controller`
4. Verify storage class: `kubectl get storageclass nfs-csi`
