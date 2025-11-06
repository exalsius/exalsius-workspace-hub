# Hackathon Slurm Cluster - Quick Start Guide

This guide describes the steps to deploy a production-ready Slurm cluster with GPU nodes, LDAP authentication, and accounting for hackathon use.

## Prerequisites

- Kubernetes cluster with GPU nodes
- `kubectl` configured
- Helm 3.0+
- NFS storage class available (`nfs-csi`)
- Storage class for persistence (`openebs-hostpath`)

## Installation Steps

### 1. Install OpenLDAP

```bash
cd openldap
helm dependency update
helm install openldap . -n ldap --create-namespace
kubectl wait --for=condition=ready pod -l app=openldap-stack-ha -n ldap --timeout=300s
```

**Optional:** Add users and groups:

```bash
kubectl cp ldif-examples/02-groups.ldif openldap-stack-ha-0:/tmp/ -n ldap
kubectl exec -it openldap-stack-ha-0 -n ldap -- \
  ldapadd -x -D "cn=admin,dc=exalsius,dc=ai" -w "Not@SecurePassw0rd" -f /tmp/02-groups.ldif
```

### 2. Install MariaDB Operator

```bash
cd ../mariadb-operator
helm dependency update
helm install mariadb-operator . -n slurm --create-namespace
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=mariadb-operator -n slurm --timeout=300s
```

### 3. Install Slurm Cluster

```bash
cd ../slurm-v25.05
helm install hackathon-cluster . -f values-hackathon-2nodes-2gpu.yaml -n slurm
```

**Wait for all pods to be ready:**

```bash
kubectl get pods -n slurm -w
```

## Cluster Features

This setup provides:

- **2 GPU compute nodes** (MI300X with ROCm)
- **Login node** with SSH access (LDAP authentication)
- **Slurm accounting** (MariaDB backend)
- **REST API** for job submission
- **Shared NFS storage** (4TB for home directories)

## Access the Cluster

### SSH to Login Node

```bash
# Get the NodePort
kubectl get svc -n slurm | grep login

# SSH to login node (use testuser if you added it to LDAP)
ssh -p <nodeport> testuser@<node-ip>
```

### Submit Jobs

Once logged in:

```bash
# Check available nodes
sinfo

# Submit a test job
srun --ntasks=1 hostname

# Check job accounting
sacct
```

## Troubleshooting

```bash
# Check LDAP
kubectl get pods -n ldap
kubectl logs -n ldap openldap-stack-ha-0

# Check MariaDB operator
kubectl get pods -n slurm | grep mariadb
kubectl get mariadb -n slurm

# Check Slurm components
kubectl get pods -n slurm
kubectl logs -n slurm <controller-pod>
```

## Uninstall

```bash
# Remove in reverse order
helm uninstall hackathon-cluster -n slurm
helm uninstall mariadb-operator -n slurm
helm uninstall openldap -n ldap

# Clean up namespaces
kubectl delete namespace slurm
kubectl delete namespace ldap
```

## Documentation

For detailed documentation, see:

- [OpenLDAP Chart](openldap/README.md)
- [MariaDB Operator Chart](mariadb-operator/README.md)
- [Slurm Chart](slurm-v25.05/README.md)

