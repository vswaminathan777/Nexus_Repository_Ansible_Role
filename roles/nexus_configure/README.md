---
# Nexus Configure Role

A dedicated Ansible role for managing post-deployment configuration of Sonatype Nexus Repository Pro. This role handles all configuration aspects including blob stores, repositories, content selectors, privileges, and roles.

## Overview

This role is designed to work in conjunction with the [`nexus_repo_pro`](../nexus_repo_pro/README.md) deployment role. It follows Ansible best practices by separating:

- **Deployment concerns** (handled by `nexus_repo_pro`): installation, service startup, health checks
- **Configuration concerns** (handled by `nexus_configure`): repositories, access control, storage

## Requirements

- Ansible >= 2.14
- `nexus_repo_pro` role deployed and running
- Nexus service must be accessible and responding to API calls
- Python 3.6+ with `requests` module

## Dependencies

This role depends on the `nexus_repo_pro` role being executed first. The playbook handles this:

```yaml
roles:
  - nexus_repo_pro    # Install and start Nexus
  - nexus_configure   # Configure Nexus
```

## Role Variables

### API Connectivity

```yaml
nexus_healthcheck_scheme: "http"      # API scheme (http/https)
nexus_healthcheck_host: "127.0.0.1"   # API host
nexus_healthcheck_port: "8081"        # API port
nexus_admin_username: "admin"         # Admin username
nexus_admin_password: "admin123"      # Admin password
```

### Feature Flags

Enable/disable specific configuration tasks:

```yaml
nexus_manage_blobstores: true          # Manage blob stores
nexus_manage_repositories: true        # Manage repositories
nexus_content_selectors_manage: true   # Manage content selectors
nexus_privileges_manage: true          # Manage privileges
nexus_roles_manage: true               # Manage roles
```

### Configuration Data

```yaml
# Blob stores configuration
nexus_blobstores: []

# Repositories configuration
nexus_repositories: []

# Content selectors configuration
nexus_content_selectors: []

# Privileges configuration
nexus_privileges: []

# Roles configuration
nexus_roles: []
```

## Usage

### Basic Playbook

```yaml
---
- name: Deploy and configure Nexus
  hosts: nexus
  become: true
  roles:
    - nexus_repo_pro      # Deployment
    - nexus_configure     # Configuration
```

### With Inventory Variables

Define configuration in your inventory group variables (`inventory/group_vars/nexus/nexus.yml`):

```yaml
# Deployment role variables
nexus_version: "3.84.1-01"
nexus_postgres_host: "db.example.com"
nexus_postgres_password: "secret"

# Configuration role variables
nexus_admin_password: "new_secure_password"

nexus_blobstores:
  - name: default
    type: file
    path: /storage/nexus-blobs/default

nexus_repositories:
  - name: maven-releases
    format: maven2
    type: hosted
    blob_store: default
    
nexus_roles:
  - id: developer
    name: Developer Role
    privileges:
      - "repository-view-maven2-*"
```

## Task Breakdown

The role executes configuration in the following sequence:

1. **Blob Stores** - Creates file and S3 blob stores
2. **Repositories** - Creates Maven, NPM, and Docker repositories
3. **Content Selectors** - Defines content selector expressions
4. **Privileges** - Creates repository, application, and content-selector privileges
5. **Roles** - Defines roles and assigns privileges

## Examples

### Minimal Configuration

```yaml
roles:
  - nexus_repo_pro
  - nexus_configure
vars:
  nexus_admin_password: "secure_password"
```

### Full Configuration Example

See the inventory examples in [inventory/group_vars/nexus/](../../inventory/group_vars/nexus/) for complete examples.

## Blob Store Types

### File Blob Store

```yaml
nexus_blobstores:
  - name: my-blobs
    type: file
    path: /storage/nexus-blobs/my-blobs
    softQuota:
      type: spaceRemainingQuota
      limit: 10737418240  # 10GB
```

### S3 Blob Store

```yaml
nexus_blobstores:
  - name: my-s3-blobs
    type: s3
    bucket: nexus-blobs
    region: us-east-1
    aws_access_key_id: "AKIA..."
    aws_secret_access_key: "..."
```

## Repository Types

Supported repository types (format_type):

- `maven2_hosted` - Maven hosted repository
- `maven2_proxy` - Maven proxy repository
- `maven2_group` - Maven group repository
- `npm_hosted` - NPM hosted repository
- `npm_proxy` - NPM proxy repository
- `npm_group` - NPM group repository
- `docker_hosted` - Docker hosted repository
- `docker_proxy` - Docker proxy repository
- `docker_group` - Docker group repository

## Privileges

Three types of privileges can be created:

### Repository-View Privileges

Access to specific repository formats/repositories:

```yaml
- type: repository-view
  name: view-maven2
  format: maven2
  repository: "maven-*"  # Wildcard supported
  actions: [READ, BROWSE, EDIT, ADD, DELETE]
```

### Application Privileges

System administration privileges:

```yaml
- type: application
  name: admin-users
  domain: userschangepw
  actions: [CREATE, READ, UPDATE, DELETE]
```

### Content-Selector Privileges

Content-filtered access:

```yaml
- type: repository-content-selector
  name: selector-releases
  selector: release-selector
  format: maven2
  repository: "maven-*"
  actions: [READ, BROWSE]
```

## Idempotency

This role is fully idempotent. Running it multiple times with the same variables will:

- Detect existing resources
- Only create or update changed resources
- Never delete resources accidentally

## Handlers

No handlers are defined in this role. Configuration changes do not require Nexus service restarts.

## Limitations

- Deleting resources is not currently supported (to prevent accidental data loss)
- User management must be done separately via `nexus_users` in your inventory
- This role assumes basic auth is available (LDAP/OAuth not yet supported)

## Testing

To test the role locally with Docker:

```bash
# Build Nexus container
docker run -d -p 8081:8081 sonatype/nexus3:latest

# Update inventory to point to localhost
ansible-playbook playbooks/deploy.yml -i localhost, -e "ansible_connection=local"
```

## Troubleshooting

### API Connection Errors

Ensure Nexus is running and accessible:

```bash
curl -u admin:admin123 http://localhost:8081/service/rest/v1/status
```

### Resource Not Found

Check that referenced resources exist (e.g., blob stores for repositories).

### Permission Denied

Verify admin credentials in inventory/group_vars.

## References

- [Nexus Repository REST API](https://help.sonatype.com/repomanager3/latest/rest-api)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Nexus Repository Documentation](https://help.sonatype.com/repomanager3/)

## License

MIT
