# Password Management Guide

## Changing Nexus Admin Password

### **Step 1: Update Vault with New Password**

```bash
EDITOR=nano ansible-vault edit inventory/group_vars/nexus/secrets.yml
```

Change the `vault_nexus_admin_password`:

```yaml
---
vault_nexus_postgres_password: "secret"
vault_nexus_admin_password: "new_admin_password_here"
```

Save and exit.

---

### **Step 2: Run Configuration with Current Password**

```bash
ansible-playbook -i inventory/hosts.yml playbooks/nexus-playbook.yml \
  --tags configuration \
  -e "nexus_admin_password_current=admin123" \
  -l nexus01 -vv
```

**Parameters:**
- `nexus_admin_password_current`: The **CURRENT** password in Nexus (for authentication)
- `nexus_admin_password`: The **NEW** password (from vault)

---

### **Step 3: Verify Password Changed**

```bash
# Test with new password (from inside Nexus container or via API)
curl -u admin:new_admin_password_here http://localhost:8081/service/rest/v1/status
```

---

## Example Scenarios

### **Scenario 1: First-Time Password Change**

Current Nexus password: `admin123`
Want to change to: `MySecurePassword456!`

```bash
# 1. Update vault
EDITOR=nano ansible-vault edit inventory/group_vars/nexus/secrets.yml
# Change: vault_nexus_admin_password: "MySecurePassword456!"

# 2. Run configuration
ansible-playbook -i inventory/hosts.yml playbooks/nexus-playbook.yml \
  --tags configuration \
  -e "nexus_admin_password_current=admin123" \
  -l nexus01 -vv
```

---

### **Scenario 2: Change Password Again**

Current Nexus password: `MySecurePassword456!`
Want to change to: `NewPassword789!`

```bash
# 1. Update vault
EDITOR=nano ansible-vault edit inventory/group_vars/nexus/secrets.yml
# Change: vault_nexus_admin_password: "NewPassword789!"

# 2. Run configuration
ansible-playbook -i inventory/hosts.yml playbooks/nexus-playbook.yml \
  --tags configuration \
  -e "nexus_admin_password_current=MySecurePassword456!" \
  -l nexus01 -vv
```

---

### **Scenario 3: Change Password for All Nodes**

```bash
ansible-playbook -i inventory/hosts.yml playbooks/nexus-playbook.yml \
  --tags configuration \
  -e "nexus_admin_password_current=admin123" \
  -vv
```

(No `-l nexus01` means all hosts in inventory)

---

## How It Works

1. **Vault stores**: The **NEW** password (`vault_nexus_admin_password`)
2. **Command line provides**: The **CURRENT** password (`nexus_admin_password_current`)
3. **Ansible tasks**:
   - Uses **current password** to authenticate to Nexus API
   - Sends **new password** to change-password endpoint
   - Nexus updates the admin password

---

## Troubleshooting

### "HTTP 401: Unauthorized"

The `nexus_admin_password_current` is incorrect. **Check the actual password in Nexus.**

```bash
# If you don't know the current password, you may need to:
# 1. Access Nexus directly via UI
# 2. Use the initial auto-generated password from first deployment:
cat /opt/sonatype/sonatype-work/nexus3/admin.password
```

### "Status code was 204 but expected 200"

This is OK! Code 204 means "No Content" which is a success. The password was changed.

### Forgot the Current Password

You'll need to reset Nexus manually or use an alternative authentication method:
- Reset via Nexus UI (if you have another admin user)
- Direct database access
- Nexus recovery/admin account

---

## Best Practices

✅ **DO:**
- Store new passwords in encrypted vault
- Always provide the current password on command line
- Document when you change passwords
- Test with curl after changing:
  ```bash
  curl -u admin:new_password http://localhost:8081/service/rest/v1/status
  ```

❌ **DON'T:**
- Commit passwords to git (only encrypted vault files)
- Use the same password across multiple environments
- Change password without updating vault
- Forget to use `EDITOR=nano` if vi is not installed

---

## One-Liner for Quick Reference

```bash
# Format: ansible-playbook ... -e "nexus_admin_password_current=<CURRENT>" 
# where new password comes from vault

ansible-playbook -i inventory/hosts.yml playbooks/nexus-playbook.yml \
  --tags configuration \
  -e "nexus_admin_password_current=admin123" \
  -vv
```
