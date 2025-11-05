#!/bin/bash
set -euo pipefail

# Script to create 50 team users (team00-team49) with LDAP, home directories, and Slurm accounting
# Can be run in login pod or init container

# Configuration via environment variables
LDAP_URI="${LDAP_URI:-ldap://ldap.slurm.svc.cluster.local:389}"
LDAP_ADMIN_DN="${LDAP_ADMIN_DN:-cn=admin,dc=exalsius,dc=ai}"
LDAP_ADMIN_PASSWORD="${LDAP_ADMIN_PASSWORD:-Not@SecurePassw0rd}"
LDAP_BASE_DN="${LDAP_BASE_DN:-dc=exalsius,dc=ai}"
LDAP_USER_OU="${LDAP_USER_OU:-ou=users,dc=exalsius,dc=ai}"
LDAP_GROUP_OU="${LDAP_GROUP_OU:-ou=groups,dc=exalsius,dc=ai}"

SLURM_CLUSTER_NAME="${SLURM_CLUSTER_NAME:-hackathon-cluster}"
SLURM_ACCOUNT_NAME="${SLURM_ACCOUNT_NAME:-team}"
SLURM_QOS_NAME="${SLURM_QOS_NAME:-team-qos}"
SLURM_NAMESPACE="${NAMESPACE:-slurm}"

NUM_USERS="${NUM_USERS:-20}"
START_INDEX="${START_INDEX:-0}"
PASSWORDS_FILE="${PASSWORDS_FILE:-/tmp/passwords.csv}"
HOME_BASE="${HOME_BASE:-/home}"

# Shared group GIDs
GID_HACKATHON=20010
GID_KVM=992
GID_RENDER=991
GID_VIDEO=44

# UID/GID range for users
UID_BASE=30000
GID_BASE=30000

# Logging functions
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_warn() {
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

# Generate random password
generate_password() {
    local length="${1:-16}"
    tr -dc 'A-Za-z0-9!@#$%^&*()_+-=' < /dev/urandom | head -c "$length" || \
    openssl rand -base64 12 | tr -d "=+/" | cut -c1-16
}

# Generate SSHA password hash
generate_ssha_hash() {
    local password="$1"
    slappasswd -s "$password" -h "{SSHA}" 2>/dev/null || {
        # Fallback if slappasswd not available
        log_warn "slappasswd not available, using python fallback"
        python3 -c "
import hashlib
import base64
import os
salt = os.urandom(4)
sha = hashlib.sha1('${password}'.encode())
sha.update(salt)
hash_b64 = base64.b64encode(sha.digest() + salt).decode()
print(f'{{SSHA}}{hash_b64}')
"
    }
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if sacctmgr query returns results (reliable existence check)
sacctmgr_exists() {
    local out
    out=$(sacctmgr $1 2>/dev/null | tr -d '[:space:]')
    # sacctmgr prints nothing if there are no rows when -nP is used
    [ -n "$out" ]
}

# Validate prerequisites
check_prerequisites() {
    local missing=()
    
    if ! command_exists ldapmodify; then
        missing+=("ldap-utils (ldapmodify)")
    fi
    
    if ! command_exists ldapadd; then
        missing+=("ldap-utils (ldapadd)")
    fi
    
    if ! command_exists sacctmgr; then
        log_warn "sacctmgr not found - Slurm accounting setup will be skipped"
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing[*]}"
        log_error "Install with: apt-get update && apt-get install -y ldap-utils"
        return 1
    fi
    
    return 0
}

# Test LDAP connection
test_ldap_connection() {
    log_info "Testing LDAP connection to ${LDAP_URI}..."
    
    if ldapwhoami -H "$LDAP_URI" -x -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" >/dev/null 2>&1; then
        log_info "LDAP connection successful"
        return 0
    else
        log_error "LDAP connection failed"
        return 1
    fi
}

# Check if user already exists in LDAP
ldap_user_exists() {
    local username="$1"
    ldapsearch -H "$LDAP_URI" -x -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" \
        -b "$LDAP_USER_OU" "(uid=$username)" dn 2>/dev/null | grep -q "^dn:"
}

# Check if group already exists in LDAP
ldap_group_exists() {
    local groupname="$1"
    ldapsearch -H "$LDAP_URI" -x -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" \
        -b "$LDAP_GROUP_OU" "(cn=$groupname)" dn 2>/dev/null | grep -q "^dn:"
}

# Create LDAP user
create_ldap_user() {
    local username="$1"
    local uid="$2"
    local gid="$3"
    local password_hash="$4"
    local temp_ldif
    
    temp_ldif=$(mktemp)
    
    # Create primary group LDIF
    cat > "$temp_ldif" <<EOF
# Primary group for ${username}
dn: cn=${username},${LDAP_GROUP_OU}
objectClass: top
objectClass: posixGroup
cn: ${username}
gidNumber: ${gid}
memberUid: ${username}

# User entry
dn: cn=${username},${LDAP_USER_OU}
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
objectClass: posixAccount
cn: ${username}
sn: ${username}
givenName: ${username^}
displayName: ${username}
uid: ${username}
uidNumber: ${uid}
gidNumber: ${gid}
loginShell: /bin/bash
homeDirectory: ${HOME_BASE}/${username}
mail: ${username}@hackathon.ai
userPassword: ${password_hash}
EOF
    
    # Add user and primary group
    if ldapadd -H "$LDAP_URI" -x -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f "$temp_ldif" 2>/dev/null; then
        rm -f "$temp_ldif"
        return 0
    else
        log_error "Failed to create LDAP user ${username}"
        rm -f "$temp_ldif"
        return 1
    fi
}

# Add user to shared groups
add_user_to_groups() {
    local username="$1"
    local temp_ldif
    
    temp_ldif=$(mktemp)
    
    cat > "$temp_ldif" <<EOF
dn: cn=hackathon,${LDAP_GROUP_OU}
changetype: modify
add: memberUid
memberUid: ${username}

dn: cn=kvm,${LDAP_GROUP_OU}
changetype: modify
add: memberUid
memberUid: ${username}

dn: cn=render,${LDAP_GROUP_OU}
changetype: modify
add: memberUid
memberUid: ${username}

dn: cn=video,${LDAP_GROUP_OU}
changetype: modify
add: memberUid
memberUid: ${username}
EOF
    
    if ldapmodify -H "$LDAP_URI" -x -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f "$temp_ldif" 2>/dev/null; then
        rm -f "$temp_ldif"
        return 0
    else
        log_warn "Failed to add ${username} to shared groups (may already be member)"
        rm -f "$temp_ldif"
        return 1
    fi
}

# Create home directory
create_home_directory() {
    local username="$1"
    local uid="$2"
    local gid="$3"
    local home_dir="${HOME_BASE}/${username}"
    
    if [ ! -d "$home_dir" ]; then
        mkdir -p "$home_dir"
        chown "${uid}:${gid}" "$home_dir"
        chmod 755 "$home_dir"
        log_info "Created home directory ${home_dir}"
        return 0
    else
        log_info "Home directory ${home_dir} already exists, skipping"
        return 0
    fi
}

# Create dataset symlink in user's home directory
create_dataset_symlink() {
    local username="$1"
    local home_dir="${HOME_BASE}/${username}"
    local symlink_path="${home_dir}/xray-data"
    local target_path="/home/datasets/xray-data"
    
    # Check if symlink already exists and points to correct target
    if [ -L "$symlink_path" ]; then
        local current_target
        current_target=$(readlink -f "$symlink_path" 2>/dev/null || readlink "$symlink_path" 2>/dev/null || echo "")
        if [ "$current_target" = "$target_path" ]; then
            log_info "Symlink ${symlink_path} already exists and points to correct target, skipping"
            return 0
        fi
    fi
    
    # If file/directory exists but is not the correct symlink, remove it
    if [ -e "$symlink_path" ]; then
        rm -f "$symlink_path"
        log_warn "Removed existing ${symlink_path} before creating symlink"
    fi
    
    # Create the symlink
    if ln -s "$target_path" "$symlink_path" 2>/dev/null; then
        log_info "Created symlink ${symlink_path} -> ${target_path}"
        return 0
    else
        log_warn "Failed to create symlink ${symlink_path} -> ${target_path}"
        return 1
    fi
}

# Setup Slurm accounting
setup_slurm_accounting() {
    if ! command_exists sacctmgr; then
        log_warn "sacctmgr not available, skipping Slurm accounting setup"
        return 0
    fi
    
    log_info "Setting up Slurm accounting..."
    
    # (Usually the cluster is auto-registered by slurmctld/slurmdbd handshake)
    
    # Ensure QoS
    if ! sacctmgr_exists "show qos where name=$SLURM_QOS_NAME -nP"; then
        log_info "Creating QoS: ${SLURM_QOS_NAME} (MaxJobsPerUser=2, MaxWall=01:00:00)"
        sacctmgr -i add qos "$SLURM_QOS_NAME" MaxJobsPerUser=2 MaxSubmitJobs=10 MaxWall=01:00:00 || {
            log_warn "QoS creation may have failed"
        }
    fi
    
    # Ensure account
    if ! sacctmgr_exists "show account where name=$SLURM_ACCOUNT_NAME -nP"; then
        log_info "Creating Slurm account: ${SLURM_ACCOUNT_NAME}"
        # Organization/Description are optional but helpful
        sacctmgr -i add account name="$SLURM_ACCOUNT_NAME" Organization=hackathon Description="Hackathon team" || {
            log_warn "Account creation may have failed"
        }
    fi
}

# Add user to Slurm accounting
add_slurm_user() {
    local username="$1"
    
    if ! command_exists sacctmgr; then
        return 0
    fi
    
    if ! sacctmgr_exists "show assoc where user=$username and account=$SLURM_ACCOUNT_NAME and cluster=$SLURM_CLUSTER_NAME -nP"; then
        log_info "Adding association ${SLURM_CLUSTER_NAME}/${SLURM_ACCOUNT_NAME}/${username}"
        sacctmgr -i add user name="$username" account="$SLURM_ACCOUNT_NAME" cluster="$SLURM_CLUSTER_NAME" DefaultAccount="$SLURM_ACCOUNT_NAME" qos="$SLURM_QOS_NAME" || {
            log_warn "Failed to add association for ${username}"
            return 1
        }
    else
        sacctmgr -i modify user where name="$username" and cluster="$SLURM_CLUSTER_NAME" \
            set qos="$SLURM_QOS_NAME" DefaultAccount="$SLURM_ACCOUNT_NAME" || \
            log_warn "Failed to set QoS/DefaultAccount for ${username}"
    fi
    
    return 0
}

# Main user creation function
create_user() {
    local index="$1"
    local username="team$(printf "%02d" "$index")"
    local uid=$((UID_BASE + index))
    local gid=$((GID_BASE + index))
    local user_exists=false
    
    log_info "Creating user: ${username} (UID: ${uid}, GID: ${gid})"
    
    # Check if user already exists
    if ldap_user_exists "$username"; then
        log_info "LDAP user ${username} already exists, skipping LDAP creation"
        user_exists=true
    else
        # Generate password
        local password
        password=$(generate_password 16)
        local password_hash
        password_hash=$(generate_ssha_hash "$password")
        
        # Create LDAP user and primary group
        if ! create_ldap_user "$username" "$uid" "$gid" "$password_hash"; then
            log_error "Failed to create LDAP user ${username}"
            return 1
        fi
        
        # Add user to shared groups
        add_user_to_groups "$username"
        
        # Save password to CSV
        echo "${username},${password}" >> "$PASSWORDS_FILE"
    fi
    
    # Create home directory (only if it doesn't exist)
    if ! create_home_directory "$username" "$uid" "$gid"; then
        log_warn "Failed to create home directory for ${username}"
    fi
    
    # Create dataset symlink (only if it doesn't exist)
    create_dataset_symlink "$username"
    
    # Add to Slurm accounting (only if association doesn't exist)
    add_slurm_user "$username"
    
    if [ "$user_exists" = true ]; then
        log_info "Successfully updated user: ${username}"
    else
        log_info "Successfully created user: ${username}"
    fi
    
    return 0
}

# Main execution
main() {
    log_info "Starting team user creation script"
    log_info "Configuration:"
    log_info "  LDAP URI: ${LDAP_URI}"
    log_info "  LDAP Admin DN: ${LDAP_ADMIN_DN}"
    log_info "  Slurm Cluster: ${SLURM_CLUSTER_NAME}"
    log_info "  Slurm Account: ${SLURM_ACCOUNT_NAME}"
    log_info "  Slurm QoS: ${SLURM_QOS_NAME}"
    log_info "  Number of users: ${NUM_USERS}"
    log_info "  Starting index: ${START_INDEX}"
    log_info "  Home base: ${HOME_BASE}"
    log_info "  Passwords file: ${PASSWORDS_FILE}"
    
    # Check prerequisites
    if ! check_prerequisites; then
        exit 1
    fi
    
    # Test LDAP connection
    if ! test_ldap_connection; then
        log_error "Cannot proceed without LDAP connection"
        exit 1
    fi
    
    # Initialize passwords CSV
    echo "username,password" > "$PASSWORDS_FILE"
    chmod 600 "$PASSWORDS_FILE"
    
    # Setup Slurm accounting (once)
    setup_slurm_accounting
    
    # Create users
    local success_count=0
    local fail_count=0
    local end_index=$((START_INDEX + NUM_USERS - 1))
    
    for i in $(seq "$START_INDEX" "$end_index"); do
        if create_user "$i"; then
            ((success_count++)) || true
        else
            ((fail_count++)) || true
        fi
    done
    
    log_info "User creation complete: ${success_count} successful, ${fail_count} failed"
    log_info "Passwords saved to: ${PASSWORDS_FILE}"
    
    # Verify Slurm associations
    if command_exists sacctmgr; then
        log_info "Verifying Slurm associations:"
        local verify_output
        verify_output=$(sacctmgr show assoc where account="$SLURM_ACCOUNT_NAME" cluster="$SLURM_CLUSTER_NAME" format=Cluster,Account,User -P 2>&1)
        if [ $? -eq 0 ] && [ -n "$verify_output" ]; then
            echo "$verify_output"
        else
            log_warn "Failed to show Slurm associations (this may be normal if no associations exist)"
            log_info "Attempting simple query..."
            sacctmgr show assoc format=Cluster,Account,User -P 2>&1 | grep -E "(^$SLURM_CLUSTER_NAME|^Cluster)" || true
        fi
    fi
    
    if [ $fail_count -gt 0 ]; then
        log_warn "Some users failed to create. Check logs above."
        exit 1
    fi
    
    return 0
}

# Run main function
main "$@"

