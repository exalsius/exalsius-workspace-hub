# Hackathon Slurm Cluster

This configuration provides a production-ready Slurm cluster optimized for hackathon use with GPU and CPU compute nodes, MariaDB accounting, REST API access, and QoS limits.

## Overview

The hackathon cluster includes:

- **4 GPU Workers**: 30 CPU cores, 400Gi RAM, 2x AMD GPUs, 200Gi storage each
- **4 CPU Workers**: 10 CPU cores, 80Gi RAM, 50Gi storage each
- **2 Partitions**: `gpu` (GPU nodes) and `cpu` (CPU nodes, default)
- **MariaDB Accounting**: Automatic database provisioning with operator
- **REST API**: Available on port 6820 for programmatic access
- **SSH Access**: Login nodes for interactive development
- **Prometheus Metrics**: Full monitoring with ServiceMonitor support
- **QoS Limits**: Per-user job and resource limits

## Quick Start

### 1. Deploy the Cluster

```bash
# Install with hackathon configuration
helm install hackathon-cluster . \
  -f values-hackathon.yaml \
  --namespace slurm \
  --create-namespace

# Wait for all components to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=slurm -n slurm --timeout=300s
```

### 2. Verify Deployment

```bash
# Check cluster status
kubectl get pods -n slurm

# Check Slurm cluster status
kubectl exec -n slurm deployment/slurm-controller -- sinfo

# Check QoS configuration
kubectl exec -n slurm deployment/slurm-controller -- sacctmgr show qos
```

### 3. Access the Cluster

#### SSH Access (Login Nodes)
```bash
# Get the login node service IP
kubectl get svc -n slurm | grep slinky

# SSH into login node (replace with your SSH key)
ssh root@<login-node-ip>
```

#### REST API Access
```bash
# Port forward to access REST API locally
kubectl port-forward -n slurm svc/slurm-restapi 6820:6820

# Test API access
curl http://localhost:6820/slurm/v0.0.36/diag
```

## Configuration Details

### NodeSets

#### GPU Workers (`gpu-workers`)
- **Replicas**: 4
- **Resources**: 30 CPU, 400Gi RAM, 2x AMD GPUs
- **Storage**: 200Gi at `/data` (OpenEBS hostpath)
- **Image**: `ghcr.io/slinkyproject/slurm-compute:latest`

#### CPU Workers (`cpu-workers`)
- **Replicas**: 4
- **Resources**: 10 CPU, 80Gi RAM
- **Storage**: 50Gi at `/data` (OpenEBS hostpath)
- **Image**: `ghcr.io/slinkyproject/slurm-compute:latest`

### Partitions

#### GPU Partition
- **Name**: `gpu`
- **Nodes**: `gpu-workers[0-3]`
- **Max Time**: 3 days
- **Default**: No
- **QoS**: `hackathon`

#### CPU Partition
- **Name**: `cpu`
- **Nodes**: `cpu-workers[0-3]`
- **Max Time**: 3 days
- **Default**: Yes
- **QoS**: `hackathon`

### QoS Limits

The `hackathon` QoS enforces the following limits per user:

- **Max Jobs**: 4 concurrent jobs
- **Max Submit Jobs**: 20 jobs in queue
- **Max Resources**: 40 CPU cores, 300Gi RAM, 4 GPUs total

### Scheduler Configuration

- **Priority Type**: `priority/multifactor`
- **Fairshare Weight**: 100,000
- **Decay Half-life**: 14 days
- **Calculation Period**: 5 minutes

## Usage Examples

### Submit Jobs

#### CPU Job
```bash
# Submit to default CPU partition
sbatch --job-name=cpu-job --cpus-per-task=4 --mem=8G <<EOF
#!/bin/bash
echo "Running on CPU node"
hostname
nproc
free -h
EOF
```

#### GPU Job
```bash
# Submit to GPU partition
sbatch --partition=gpu --job-name=gpu-job --cpus-per-task=8 --mem=32G --gres=gpu:1 <<EOF
#!/bin/bash
echo "Running on GPU node"
hostname
nvidia-smi
EOF
```

#### Interactive Session
```bash
# Interactive CPU session
srun --partition=cpu --cpus-per-task=4 --mem=8G --pty bash

# Interactive GPU session
srun --partition=gpu --cpus-per-task=8 --mem=32G --gres=gpu:1 --pty bash
```

### Monitor Jobs

```bash
# List jobs
squeue

# Check job details
scontrol show job <job-id>

# Check accounting
sacct -j <job-id>
```

### REST API Examples

```bash
# Get cluster information
curl http://localhost:6820/slurm/v0.0.36/diag

# List jobs
curl http://localhost:6820/slurm/v0.0.36/jobs

# Submit job via API
curl -X POST http://localhost:6820/slurm/v0.0.36/job/submit \
  -H "Content-Type: application/json" \
  -d '{
    "job": {
      "name": "api-job",
      "partition": "cpu",
      "cpus_per_task": 4,
      "memory_per_cpu": "2G",
      "script": "#!/bin/bash\necho Hello from API job"
    }
  }'
```

## Monitoring

### Prometheus Metrics

The cluster exports Prometheus metrics for:

- Queue status and job counts
- Node utilization and availability
- Job statistics and completion rates
- Resource usage per partition

Access metrics at: `http://<slurm-exporter-service>:8080/metrics`

### ServiceMonitor

If you have kube-prometheus-stack installed, the ServiceMonitor is automatically created to scrape Slurm metrics.

## Troubleshooting

### Common Issues

#### 1. Jobs Stuck in Pending
```bash
# Check node status
sinfo

# Check job details
scontrol show job <job-id>

# Check resource availability
sinfo -o "%P %A %C %G"
```

#### 2. GPU Jobs Not Starting
```bash
# Verify GPU nodes are available
sinfo -p gpu -o "%N %T %G"

# Check GRES configuration
scontrol show config | grep Gres
```

#### 3. QoS Limits Exceeded
```bash
# Check current usage
sacct -u $USER --start=today

# Check QoS limits
sacctmgr show qos hackathon
```

#### 4. Storage Issues
```bash
# Check storage on compute nodes
kubectl exec -n slurm deployment/slurm-gpu-workers-0 -- df -h /data
kubectl exec -n slurm deployment/slurm-cpu-workers-0 -- df -h /data
```

### Debug Commands

```bash
# Check Slurm configuration
kubectl exec -n slurm deployment/slurm-controller -- cat /etc/slurm/slurm.conf

# Check controller logs
kubectl logs -n slurm deployment/slurm-controller

# Check compute node logs
kubectl logs -n slurm deployment/slurm-gpu-workers-0
kubectl logs -n slurm deployment/slurm-cpu-workers-0

# Check MariaDB status
kubectl get mariadb -n slurm
kubectl logs -n slurm deployment/mariadb
```

## Customization

### Adding SSH Keys

Edit `values-hackathon.yaml` and add your SSH public keys:

```yaml
slurm:
  loginsets:
    slinky:
      login:
        rootSshAuthorizedKeys: |
          ssh-ed25519 AAAA... your-key-here
          ssh-rsa AAAA... another-key-here
```

### Adjusting Resource Limits

Modify the QoS limits by updating the QoS setup job template or running:

```bash
kubectl exec -n slurm deployment/slurm-controller -- sacctmgr -i modify qos hackathon MaxJobsPerUser=8
```

### Scaling Nodes

To add more compute nodes, update the replicas in `values-hackathon.yaml`:

```yaml
slurm:
  nodesets:
    gpu-workers:
      replicas: 8  # Increase from 4 to 8
    cpu-workers:
      replicas: 8  # Increase from 4 to 8
```

## Cleanup

To remove the cluster:

```bash
# Delete the Helm release
helm uninstall hackathon-cluster -n slurm

# Delete the namespace (optional)
kubectl delete namespace slurm
```

## Support

For issues with this configuration:

1. Check the troubleshooting section above
2. Review Slurm logs: `kubectl logs -n slurm deployment/slurm-controller`
3. Verify cluster status: `kubectl exec -n slurm deployment/slurm-controller -- sinfo`
4. Check MariaDB status: `kubectl get mariadb -n slurm`
