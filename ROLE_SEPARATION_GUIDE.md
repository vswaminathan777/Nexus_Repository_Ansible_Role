# Ansible Role Separation - Migration Guide

## Overview

The Nexus Repository Pro deployment project has been refactored to separate **deployment** and **configuration** concerns into two distinct Ansible roles, following best practices and enabling better code reusability, testing, and maintainability.

## Before: Combined Role

Previously, a single role (`nexus_repo_pro`) handled both:
- Nexus installation and startup
- Configuration of blob stores, repositories, privileges, and roles

This made it difficult to:
- Reuse the deployment role without configuration
- Update configuration without redeploying Nexus
- Test deployment and configuration separately
- Understand role responsibilities

## After: Separated Roles

### 1. `nexus_repo_pro` - Deployment Role

**Purpose**: Install, configure, and start Nexus Repository Pro

**Responsibilities**:
- Install Java runtime
- Download and extract Nexus archive
- Create system user and directories
- Configure Nexus properties and database connection
- Set up systemd service or direct startup
- Apply Nexus Pro license (if provided)
- Wait for Nexus to be healthy
- Set initial admin password

**Tasks**:
- `nexus.yml` - Installation and service configuration
- `wait_for_nexus.yml` - Health check
- `admin_password.yml` - Initial admin password setup
- `main.yml` - Orchestration

**Variables**: Deployment configuration (PostgreSQL, Java, ports, etc.)

**Output**: Running Nexus instance ready to accept API calls

### 2. `nexus_configure` - Configuration Role

**Purpose**: Configure Nexus with repositories, access control, and storage

**Responsibilities**:
- Create blob stores (file and S3)
- Create repositories (Maven, NPM, Docker)
- Define content selectors
- Create privileges (repository, application, content-selector)
- Create and manage roles

**Tasks**:
- `blobstores.yml` - Create and manage blob stores
- `repositories.yml` - Create and manage repositories
- `content_selectors.yml` - Create and manage content selectors
- `privileges.yml` - Create and manage privileges
- `roles.yml` - Create and manage roles
- `manage_one_repository.yml` - Helper for repository creation
- `main.yml` - Orchestration

**Variables**: Configuration data (repositories, users, privileges, etc.)

**Dependencies**: Requires `nexus_repo_pro` role (defined in meta/main.yml)

## Directory Structure

```
roles/
├── nexus_repo_pro/                    # DEPLOYMENT ROLE
│   ├── defaults/main.yml              # Deployment variables only
│   ├── handlers/main.yml
│   ├── meta/main.yml
│   ├── tasks/
│   │   ├── main.yml
│   │   ├── nexus.yml
│   │   ├── wait_for_nexus.yml
│   │   └── admin_password.yml
│   ├── templates/
│   │   ├── nexus.properties.j2
│   │   ├── nexus-store.properties.j2
│   │   └── nexus-systemd-override.conf.j2
│   ├── files/
│   │   └── sonatype-license.lic
│   └── README.md
│
└── nexus_configure/                   # CONFIGURATION ROLE (NEW)
    ├── defaults/main.yml              # Configuration variables only
    ├── handlers/main.yml              # (empty - no restarts needed)
    ├── meta/main.yml                  # Depends on nexus_repo_pro
    ├── tasks/
    │   ├── main.yml
    │   ├── blobstores.yml
    │   ├── repositories.yml
    │   ├── content_selectors.yml
    │   ├── privileges.yml
    │   ├── roles.yml
    │   └── manage_one_repository.yml
    ├── README.md                      # Detailed configuration guide
    └── (no templates or files)
```

## Playbook Changes

### Before

```yaml
roles:
  - nexus_repo_pro
```

All tasks, deployment AND configuration.

### After

```yaml
roles:
  - nexus_repo_pro      # Install and start
  - nexus_configure     # Configure after startup
```

Two separate roles execute in sequence, each with a clear purpose.

## Variable Organization

### Deployment Variables (nexus_repo_pro/defaults/main.yml)

**Core Configuration**:
```yaml
nexus_version: "3.84.1-01"
nexus_edition: "pro"
nexus_install_dir: "/opt/sonatype"
nexus_listen_port: 8081
```

**Database Configuration**:
```yaml
nexus_postgres_host: "db.example.com"
nexus_postgres_port: 5432
nexus_postgres_db: "nexus"
nexus_postgres_user: "nexus"
nexus_postgres_password: "change_me"
```

**Service Configuration**:
```yaml
nexus_use_systemd: true
nexus_service_name: "nexus"
```

**Health & Admin**:
```yaml
nexus_admin_password: "admin123"
nexus_healthcheck_retries: 30
```

### Configuration Variables (nexus_configure/defaults/main.yml)

**API Connectivity**:
```yaml
nexus_healthcheck_scheme: "http"
nexus_healthcheck_host: "127.0.0.1"
nexus_healthcheck_port: "8081"
nexus_admin_username: "admin"
nexus_admin_password: "admin123"
```

**Feature Flags**:
```yaml
nexus_manage_blobstores: true
nexus_manage_repositories: true
nexus_content_selectors_manage: true
nexus_privileges_manage: true
nexus_roles_manage: true
```

**Configuration Data**:
```yaml
nexus_blobstores: []
nexus_repositories: []
nexus_content_selectors: []
nexus_privileges: []
nexus_roles: []
```

## Inventory Structure Recommendation

### inventory/group_vars/nexus/nexus.yml

```yaml
# --- DEPLOYMENT CONFIGURATION (nexus_repo_pro) ---
nexus_version: "3.84.1-01"
nexus_edition: "pro"
nexus_listen_port: 8081
nexus_install_dir: "/opt/sonatype"

# Database
nexus_postgres_host: "{{ groups['db_servers'][0] }}"
nexus_postgres_port: 5432
nexus_postgres_db: "nexus"
nexus_postgres_user: "nexus"
nexus_postgres_password: "{{ vault_nexus_db_password }}"

# Initial admin password (change on first login!)
nexus_admin_password: "{{ vault_nexus_admin_password }}"

# --- CONFIGURATION (nexus_configure) ---
nexus_blobstores:
  - name: default
    type: file
    path: /storage/nexus-blobs/default

nexus_repositories:
  - name: maven-releases
    format: maven2
    type: hosted
    blob_store: default
    online: true

nexus_roles:
  - id: developer
    name: Developer
    privileges:
      - "repository-view-maven2-*"
```

## Migration Steps

If you have an existing playbook:

1. ✅ **Already Done**: Roles have been separated
2. ✅ **Already Done**: Configuration tasks moved to `nexus_configure`
3. ✅ **Already Done**: Playbook updated to use both roles
4. **You Should Do**: Update inventory to organize variables properly
5. **You Should Do**: Test with both roles in sequence

## Testing the New Structure

### Test Deployment Only

```bash
ansible-playbook playbooks/deploy.yml \
  -e "nexus_manage_blobstores=false" \
  -e "nexus_manage_repositories=false" \
  -e "nexus_content_selectors_manage=false" \
  -e "nexus_privileges_manage=false" \
  -e "nexus_roles_manage=false"
```

This will only run `nexus_repo_pro` effectively.

### Test Configuration Only

Deploy once, then run playbook again to let `nexus_configure` configure.

### Test Individual Components

```bash
# Test only blob stores
ansible-playbook playbooks/deploy.yml \
  -e "nexus_manage_repositories=false" \
  -e "nexus_content_selectors_manage=false" \
  -e "nexus_privileges_manage=false" \
  -e "nexus_roles_manage=false"
```

## Benefits of This Separation

1. **Clear Responsibility**: Each role has one job
2. **Reusability**: Use `nexus_repo_pro` without configuration elsewhere
3. **Testability**: Test deployment and configuration independently
4. **Maintainability**: Easier to understand and modify
5. **Scalability**: Add new configuration types without touching deployment
6. **Idempotency**: Run configuration role multiple times safely
7. **Flexibility**: Skip configuration if not needed
8. **Documentation**: Each role can be documented independently

## Backward Compatibility

- ✅ All variables are backward compatible
- ✅ Same playbook file structure
- ✅ No changes required to inventory organization (but recommended)
- ✅ Same end result: configured Nexus instance

## Troubleshooting

### "Skipping because condition failed"

If configuration tasks are skipped, check:
- Are the feature flags set to `true`?
- Are the configuration arrays populated (not empty)?
- Is Nexus healthy and reachable?

### "Error: Failed to connect to Nexus API"

Ensure:
- `nexus_healthcheck_host` and `nexus_healthcheck_port` match your setup
- Nexus is running (deployment role completed successfully)
- Network connectivity between control node and Nexus

### "Privilege/Role not created"

Check for:
- Invalid privilege types
- Missing required fields
- Circular role dependencies

## Next Steps

1. Review the new role READMEs:
   - [nexus_repo_pro/README.md](roles/nexus_repo_pro/README.md)
   - [nexus_configure/README.md](roles/nexus_configure/README.md)

2. Test the new structure with your inventory

3. Update CI/CD pipelines if applicable

4. Consider using role-specific tags for more granular control:
   ```bash
   ansible-playbook playbooks/deploy.yml --tags nexus_repo_pro
   ansible-playbook playbooks/deploy.yml --tags nexus_configure
   ```

5. Document any custom configurations in your inventory

## Questions?

Refer to the individual role READMEs or the main project documentation.
