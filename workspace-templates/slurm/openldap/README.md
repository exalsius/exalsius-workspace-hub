# OpenLDAP Chart

This Helm chart installs OpenLDAP Stack HA for Kubernetes, which provides user authentication and authorization services for Slurm login nodes.

## Overview

OpenLDAP Stack HA is a highly available LDAP server deployment that manages user accounts, groups, and authentication. This chart is designed to be installed as a prerequisite before installing the Slurm chart.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Sufficient cluster resources for LDAP pods

## Installation

### Install in Dedicated Namespace

It's recommended to install OpenLDAP in a dedicated `ldap` namespace to separate authentication infrastructure from compute workloads:

```bash
# Update Helm dependencies
helm dependency update

# Install OpenLDAP in the ldap namespace
helm install openldap . -n ldap --create-namespace
```

### Verify Installation

Wait for OpenLDAP to be ready:

```bash
# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=openldap-stack-ha -n ldap --timeout=300s

# Check pod status
kubectl get pods -n ldap

# Check service
kubectl get svc -n ldap
```

You should see a service named `ldap` which will be accessible at: `ldap://ldap.ldap.svc.cluster.local`

## Configuration

### values.yaml

The default `values.yaml` includes common configuration:

```yaml
openldap-stack-ha:
  enabled: true
  fullnameOverride: "ldap"
  
  global:
    ldapDomain: "exalsius.ai"
    adminUser: "admin"
    adminPassword: "Not@SecurePassw0rd"  # Change in production!
    ldapPort: 389
    sslLdapPort: 636
```

### Customizing Configuration

#### Change LDAP Domain

```yaml
openldap-stack-ha:
  global:
    ldapDomain: "mycompany.com"
```

This will create the directory structure: `dc=mycompany,dc=com`

#### Use Custom Passwords

**Recommended for production:**

```bash
# Create a secret with your passwords
kubectl create secret generic ldap-passwords \
  --from-literal=LDAP_ADMIN_PASSWORD='YourSecurePassword' \
  --from-literal=LDAP_CONFIG_ADMIN_PASSWORD='YourSecurePassword' \
  -n ldap

# Reference it in values
openldap-stack-ha:
  global:
    existingSecret: "ldap-passwords"
```

#### Enable Persistence

```yaml
openldap-stack-ha:
  persistence:
    enabled: true
    storageClass: "fast-ssd"
    size: 8Gi
```

#### Configure High Availability

```yaml
openldap-stack-ha:
  replication:
    enabled: true
    replicas: 3
```

## Adding Users and Groups

After installation, you can add users and groups using LDIF (LDAP Data Interchange Format) files.

### Using LDIF Files

Example LDIF files are provided in the `ldif-examples/` directory:

1. **Create groups** (`02-groups.ldif`):

```bash
kubectl exec -it openldap-stack-ha-0 -n ldap -- ldapadd -x \
  -D "cn=admin,dc=exalsius,dc=ai" \
  -w "Not@SecurePassw0rd" \
  -f /path/to/02-groups.ldif
```

2. **Create users** (`03-testuser.ldif`):

```bash
kubectl exec -it openldap-stack-ha-0 -n ldap -- ldapadd -x \
  -D "cn=admin,dc=exalsius,dc=ai" \
  -w "Not@SecurePassw0rd" \
  -f /path/to/03-testuser.ldif
```

3. **Add users to groups** (`04-testuser-to-groups.ldf`):

```bash
kubectl exec -it openldap-stack-ha-0 -n ldap -- ldapmodify -x \
  -D "cn=admin,dc=exalsius,dc=ai" \
  -w "Not@SecurePassw0rd" \
  -f /path/to/04-testuser-to-groups.ldf
```

### Copy LDIF Files to Pod

To copy LDIF files into the pod:

```bash
kubectl cp ldif-examples/02-groups.ldif openldap-stack-ha-0:/tmp/ -n ldap
kubectl exec -it openldap-stack-ha-0 -n ldap -- ldapadd -x \
  -D "cn=admin,dc=exalsius,dc=ai" \
  -w "Not@SecurePassw0rd" \
  -f /tmp/02-groups.ldif
```

### Using ldapsearch

Search for users:

```bash
kubectl exec -it openldap-stack-ha-0 -n ldap -- ldapsearch -x \
  -D "cn=admin,dc=exalsius,dc=ai" \
  -w "Not@SecurePassw0rd" \
  -b "ou=users,dc=exalsius,dc=ai" \
  "(objectClass=posixAccount)"
```

Search for groups:

```bash
kubectl exec -it openldap-stack-ha-0 -n ldap -- ldapsearch -x \
  -D "cn=admin,dc=exalsius,dc=ai" \
  -w "Not@SecurePassw0rd" \
  -b "ou=groups,dc=exalsius,dc=ai" \
  "(objectClass=posixGroup)"
```

## Integration with Slurm

Once OpenLDAP is installed and configured, you can install the Slurm chart which will connect to it for user authentication.

### Connection Details

- **LDAP URI**: `ldap://ldap.ldap.svc.cluster.local`
- **LDAP Port**: 389 (standard) or 636 (SSL/TLS)
- **Base DN**: `dc=exalsius,dc=ai` (or your configured domain)
- **User Base**: `ou=users,dc=exalsius,dc=ai`
- **Group Base**: `ou=groups,dc=exalsius,dc=ai`
- **Bind DN**: `cn=admin,dc=exalsius,dc=ai`

### Slurm Login Node Configuration

The Slurm login nodes will automatically connect to LDAP using SSSD. The configuration is included in the Slurm chart's `values-hackathon-2nodes-2gpu.yaml`:

```yaml
slurm:
  loginsets:
    slinky:
      sssdConf: |
        [domain/ldap]
        ldap_uri = ldap://ldap.ldap.svc.cluster.local
        ldap_search_base = dc=exalsius,dc=ai
        ldap_user_search_base = ou=users,dc=exalsius,dc=ai
        ldap_group_search_base = ou=groups,dc=exalsius,dc=ai
        ldap_default_bind_dn = cn=admin,dc=exalsius,dc=ai
        ldap_default_authtok = Not@SecurePassw0rd
```

## Troubleshooting

### Check LDAP Server Status

```bash
# Check pod logs
kubectl logs -n ldap openldap-stack-ha-0

# Check all pods in namespace
kubectl get pods -n ldap

# Describe pod for events
kubectl describe pod openldap-stack-ha-0 -n ldap
```

### Test LDAP Connection

From within the cluster:

```bash
# Create a test pod
kubectl run ldap-test --image=alpine --rm -it -n ldap -- sh

# Install ldap utilities
apk add openldap-clients

# Test connection
ldapsearch -x -H ldap://ldap.ldap.svc.cluster.local \
  -D "cn=admin,dc=exalsius,dc=ai" \
  -w "Not@SecurePassw0rd" \
  -b "dc=exalsius,dc=ai"
```

### Common Issues

1. **Pod stuck in Pending**: Check storage class if persistence is enabled
2. **Connection refused**: Ensure service is running and ports are correct
3. **Authentication failed**: Verify admin password matches configuration
4. **DNS resolution fails**: Check that the service name is `ldap` (from fullnameOverride)

### View LDAP Configuration

```bash
# Get LDAP config
kubectl exec -it openldap-stack-ha-0 -n ldap -- ldapsearch -Y EXTERNAL -H ldapi:/// -b "cn=config"
```

## Uninstallation

To uninstall OpenLDAP:

```bash
# First, remove any Slurm installations that use LDAP
helm uninstall slurm -n slurm

# Then uninstall OpenLDAP
helm uninstall openldap -n ldap

# Optionally, delete the namespace
kubectl delete namespace ldap
```

**Warning:** If persistence is enabled, you may need to manually delete PVCs:

```bash
kubectl delete pvc -n ldap --all
```

## Additional Resources

- [OpenLDAP Stack HA Chart Documentation](https://github.com/jp-gouin/helm-openldap)
- [OpenLDAP Documentation](https://www.openldap.org/doc/)
- [LDIF Format Reference](https://ldap.com/ldif-the-ldap-data-interchange-format/)
- [Slurm Chart Documentation](../slurm-v25.05/README.md)

