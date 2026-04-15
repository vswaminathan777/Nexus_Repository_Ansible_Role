# Nexus Repository Pro HA Ansible Role

This repository manages a highly available Nexus Repository Pro deployment with Ansible.

The project is split into two roles:

- `roles/nexus_repo_pro` deploys and starts Nexus nodes
- `roles/nexus_configure` configures Nexus through the REST API

This repository is intended for an environment where the surrounding infrastructure already exists and is managed outside this project.

That includes:

- PostgreSQL
- load balancer
- container or VM hosts
- shared storage and network plumbing required by Nexus HA

## What This Project Manages

The playbook configures Nexus nodes and Nexus application objects such as:

- Nexus installation and startup
- PostgreSQL connectivity settings
- HA-related Nexus configuration
- blob stores
- repositories
- content selectors
- privileges
- roles

## What This Project Assumes

- PostgreSQL is already provisioned and reachable from each Nexus node
- the Nexus nodes already exist and are reachable over SSH
- a load balancer exists if your environment requires one
- shared storage and any HA prerequisites are already in place
- the operator has the Ansible Vault password used for `inventory/group_vars/nexus/secrets.yml`

## Repository Layout

```text
.
|-- ansible.cfg
|-- requirements.yml
|-- playbooks/
|   `-- nexus-playbook.yml
|-- inventory/
|   |-- hosts.yml
|   `-- group_vars/
|       `-- nexus/
|           |-- nexus.yml
|           |-- secrets.yml
|           |-- blobstores.yml
|           |-- nexus_repositories.yml
|           |-- content_selectors.yml
|           |-- privileges.yml
|           |-- roles.yml
|           `-- users.yaml
`-- roles/
    |-- nexus_repo_pro/
    `-- nexus_configure/
```

## Important Files

- `playbooks/nexus-playbook.yml` is the main playbook
- `inventory/hosts.yml` defines the Nexus hosts
- `inventory/group_vars/nexus/nexus.yml` contains non-secret Nexus settings
- `inventory/group_vars/nexus/secrets.yml` contains encrypted secrets
- `requirements.yml` defines required Ansible collections
- `ansible.cfg` points Ansible at the inventory, roles path, and Vault password file

## Prerequisites

Before running this project, make sure you have:

- Ansible available in your execution environment
- SSH connectivity to all Nexus hosts
- access to the Vault password used for `inventory/group_vars/nexus/secrets.yml`
- Docker available if you run Ansible from a container

## Required Collections

This repository does not currently require any non-core Ansible collections.

If you later add collection-based modules, you can declare them in `requirements.yml` and install them with:

```bash
ansible-galaxy collection install -r requirements.yml
```

## Inventory Setup

Update `inventory/hosts.yml` with your Nexus hosts and SSH settings.

Example:

```yaml
all:
  vars:
    ansible_user: root
    ansible_password: rootpass
    ansible_connection: ssh
    ansible_become: true
    ansible_python_interpreter: /usr/bin/python3
  children:
    nexus:
      hosts:
        nexus01:
          ansible_host: nexus01
        nexus02:
          ansible_host: nexus02
        nexus03:
          ansible_host: nexus03
```

Adjust these values for your environment:

- `ansible_user`
- `ansible_password` or SSH key usage
- `ansible_host`
- `ansible_python_interpreter`
- SSH arguments if needed

## Group Variables

Most project configuration lives under `inventory/group_vars/nexus/`.

### Public configuration

Use `inventory/group_vars/nexus/nexus.yml` for non-secret configuration such as:

- Nexus version
- install paths
- service options
- PostgreSQL host, port, and database name
- health check settings
- load balancer hook commands

### Secret configuration

Use `inventory/group_vars/nexus/secrets.yml` for secret values such as:

- `vault_nexus_admin_password`
- `vault_nexus_postgres_password`

That file should remain encrypted with Ansible Vault.

### Configuration data files

The configuration role also reads structured definitions from:

- `inventory/group_vars/nexus/blobstores.yml`
- `inventory/group_vars/nexus/nexus_repositories.yml`
- `inventory/group_vars/nexus/content_selectors.yml`
- `inventory/group_vars/nexus/privileges.yml`
- `inventory/group_vars/nexus/roles.yml`
- `inventory/group_vars/nexus/users.yaml`

## Vault Setup

This project expects the Vault password file at:

```text
/root/.ansible/vault_pass
```

inside the execution environment currently described by `ansible.cfg`.

The relevant Ansible setting is:

```ini
[defaults]
vault_password_file = /root/.ansible/vault_pass
```

### Option 1: Running from a Linux host or Linux container

Create the Vault password file:

```bash
mkdir -p ~/.ansible
printf '%s\n' 'your-shared-vault-password' > ~/.ansible/vault_pass
chmod 600 ~/.ansible/vault_pass
```

### Option 2: Use the helper script

The repository includes a helper script:

```bash
bash setup-vault.sh
```

The script will:

- create `~/.ansible/vault_pass`
- verify the password against `inventory/group_vars/nexus/secrets.yml`
- remind you about `ansible.cfg`
- help keep Vault handling consistent

### Verify that secrets are readable

```bash
ansible-vault view inventory/group_vars/nexus/secrets.yml \
  --vault-password-file ~/.ansible/vault_pass
```

If decryption fails, the playbook will fail before it can run.

## Main Playbook

The main playbook is:

```yaml
---
- name: Deploy and configure Nexus nodes
  hosts: nexus
  become: true
  serial: 1
  max_fail_percentage: 0
  roles:
    - role: nexus_repo_pro
      tags: [deployment]
    - role: nexus_configure
      tags: [configuration]
```

### What this means

- all hosts in the `nexus` group are targeted
- privilege escalation is enabled with `become: true`
- only one node is processed at a time because of `serial: 1`
- any host failure stops the rollout because of `max_fail_percentage: 0`
- deployment and configuration both run unless you filter by tags

## How To Run

### Run everything

If you do not specify tags, both roles run:

```bash
ansible-playbook playbooks/nexus-playbook.yml -i inventory/hosts.yml
```

That runs:

- `nexus_repo_pro`
- `nexus_configure`

### Run deployment only

```bash
ansible-playbook playbooks/nexus-playbook.yml \
  -i inventory/hosts.yml \
  --tags deployment
```

### Run configuration only

```bash
ansible-playbook playbooks/nexus-playbook.yml \
  -i inventory/hosts.yml \
  --tags configuration
```

### Limit to one host

```bash
ansible-playbook playbooks/nexus-playbook.yml \
  -i inventory/hosts.yml \
  --limit nexus01
```

### Preview changes

```bash
ansible-playbook playbooks/nexus-playbook.yml \
  -i inventory/hosts.yml \
  --check
```

## Running From Docker

If you want to run Ansible from a container, mount the repository into the container and ensure the Vault password file is also available inside the container.

Example pattern:

```powershell
docker run -it --rm --network nexus-net -v C:\ansible\nexus:/work ansible-nexus
```

From there, run the playbook from the project directory:

```bash
cd /work/nexus_external_ha_project
ansible-playbook playbooks/nexus-playbook.yml -i inventory/hosts.yml
```

If `ansible.cfg` points to `/root/.ansible/vault_pass`, then your container must contain that file. Common approaches:

- bake it into the container for local-only testing
- mount it at runtime
- override the Vault setting when running Ansible

Example with an explicit Vault file argument:

```bash
ansible-playbook playbooks/nexus-playbook.yml \
  -i inventory/hosts.yml \
  --vault-password-file /root/.ansible/vault_pass
```

## Role Behavior

### `nexus_repo_pro`

This role handles node deployment tasks such as:

- installing Java
- downloading and extracting Nexus
- preparing directories
- rendering Nexus config files
- starting Nexus
- waiting for the service to become healthy
- bootstrapping the admin password

### `nexus_configure`

This role handles application-level configuration using the Nexus REST API:

- blob stores
- repositories
- content selectors
- privileges
- roles

## Rolling Deployments

The playbook uses `serial: 1`, so changes are applied one node at a time.

This is especially useful for:

- upgrades
- rolling restarts
- staged configuration updates

If a node fails, Ansible stops before moving on to the next node.

## Upgrades

To upgrade Nexus:

1. update `nexus_version` in `inventory/group_vars/nexus/nexus.yml`
2. confirm any related package or runtime settings
3. run the playbook

Because the playbook is serialized, nodes are upgraded one by one.

## Load Balancer Hooks

If you want Ansible to drain and re-add nodes during a rollout, populate these variables in `inventory/group_vars/nexus/nexus.yml`:

- `nexus_lb_drain_command`
- `nexus_lb_add_command`

If they are empty, those steps are skipped.

## Blob Stores and Repositories

You can define blob stores and repositories under:

- `inventory/group_vars/nexus/blobstores.yml`
- `inventory/group_vars/nexus/nexus_repositories.yml`

Repository examples currently include:

- Maven hosted, proxy, and group
- NPM hosted and proxy
- Docker hosted, proxy, and group

## Access Control

Access control objects are managed with:

- `inventory/group_vars/nexus/content_selectors.yml`
- `inventory/group_vars/nexus/privileges.yml`
- `inventory/group_vars/nexus/roles.yml`

Make sure names referenced across these files stay aligned. For example:

- repository names in `privileges.yml` should match repository names defined in `nexus_repositories.yml`
- privilege names referenced in `roles.yml` should exist in `privileges.yml`

## Recommended First Run Sequence

For a new environment, the safest order is:

1. update `inventory/hosts.yml`
2. update `inventory/group_vars/nexus/nexus.yml`
3. verify `inventory/group_vars/nexus/secrets.yml` is encrypted and valid
4. verify Vault access with `ansible-vault view inventory/group_vars/nexus/secrets.yml`
5. run deployment:

```bash
ansible-playbook playbooks/nexus-playbook.yml -i inventory/hosts.yml --tags deployment
```

6. run configuration:

```bash
ansible-playbook playbooks/nexus-playbook.yml -i inventory/hosts.yml --tags configuration
```

7. once validated, run the full playbook normally for repeatable operations

## Troubleshooting

### Vault password file not found

Make sure the file configured in `ansible.cfg` exists in the execution environment:

```text
/root/.ansible/vault_pass
```

### Secrets do not decrypt

Verify the Vault password:

```bash
ansible-vault view inventory/group_vars/nexus/secrets.yml \
  --vault-password-file /root/.ansible/vault_pass
```

### `ansible-playbook` not found

Install or use an environment that already contains Ansible, or run from your Ansible container image.

### Docker container cannot access the project files

Verify the repository is mounted correctly and that the working directory inside the container is the project root.

### SSH connectivity issues

Verify:

- target hostnames resolve
- SSH credentials are correct
- the target hosts allow the specified user to connect
- Python is available on the target nodes

## Notes

- `secrets.yml` should stay encrypted in version control
- the Vault password file should never be committed
- the two Vault markdown files are now ignored by Git for this workspace
