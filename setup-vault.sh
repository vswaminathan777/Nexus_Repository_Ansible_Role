#!/bin/bash
# setup-vault.sh - Team-safe Ansible Vault setup script

set -euo pipefail

VAULT_PASS_FILE="${HOME}/.ansible/vault_pass"
SECRETS_FILE="inventory/group_vars/nexus/secrets.yml"
VAULT_ID="default"

echo "Ansible Vault Setup"
echo "==================="
echo ""

mkdir -p "${HOME}/.ansible"

is_encrypted() {
    local file="$1"
    [ -f "$file" ] && head -n 1 "$file" | grep -q '^\$ANSIBLE_VAULT;'
}

write_vault_password_file() {
    local input_pass
    echo "Enter the shared vault password for this project."
    read -r -s -p "Vault password: " input_pass
    echo ""
    printf '%s\n' "$input_pass" > "$VAULT_PASS_FILE"
    chmod 600 "$VAULT_PASS_FILE"
    echo "Vault password file written to ${VAULT_PASS_FILE}"
}

verify_existing_password() {
    if [ ! -f "$VAULT_PASS_FILE" ]; then
        return 1
    fi

    chmod 600 "$VAULT_PASS_FILE" 2>/dev/null || true

    if [ -f "$SECRETS_FILE" ] && is_encrypted "$SECRETS_FILE"; then
        if ansible-vault view "$SECRETS_FILE" --vault-id "${VAULT_ID}@${VAULT_PASS_FILE}" >/dev/null 2>&1; then
            echo "Existing vault password file is valid for ${SECRETS_FILE}"
            return 0
        else
            echo "Existing vault password file does not decrypt ${SECRETS_FILE}"
            return 1
        fi
    fi

    echo "Existing vault password file found at ${VAULT_PASS_FILE}"
    return 0
}

setup_ansible_cfg() {
    if [ ! -f ansible.cfg ]; then
        echo "Creating ansible.cfg..."
        cat > ansible.cfg << EOF
[defaults]
vault_identity_list = ${VAULT_ID}@${VAULT_PASS_FILE}
EOF
        echo "ansible.cfg created"
    else
        echo "ansible.cfg already exists"
        echo "Make sure it contains one of these:"
        echo "  vault_identity_list = ${VAULT_ID}@${VAULT_PASS_FILE}"
        echo "or"
        echo "  vault_password_file = ${VAULT_PASS_FILE}"
    fi
}

encrypt_if_needed() {
    if [ ! -f "$SECRETS_FILE" ]; then
        echo "Warning: ${SECRETS_FILE} not found"
        return 0
    fi

    if is_encrypted "$SECRETS_FILE"; then
        echo "${SECRETS_FILE} is already encrypted, skipping encryption"
        return 0
    fi

    echo "Plaintext secrets file detected. Encrypting..."
    ansible-vault encrypt "$SECRETS_FILE" \
        --vault-id "${VAULT_ID}@${VAULT_PASS_FILE}" \
        --encrypt-vault-id "${VAULT_ID}"
    echo "${SECRETS_FILE} encrypted"
}

setup_gitignore() {
    if [ ! -f .gitignore ]; then
        cat > .gitignore << EOF
.vault_pass
vault_pass*
vault.key
inventory/group_vars/*/secrets.yml
EOF
        echo ".gitignore created"
    fi
}

echo "Checking vault password setup..."
if verify_existing_password; then
    :
else
    echo ""
    echo "A valid vault password file is required."
    echo "For shared repositories, use the team's existing vault password."
    echo "Do not generate a new random password unless you are creating a brand-new vault."
    echo ""
    write_vault_password_file

    if [ -f "$SECRETS_FILE" ] && is_encrypted "$SECRETS_FILE"; then
        if ! ansible-vault view "$SECRETS_FILE" --vault-id "${VAULT_ID}@${VAULT_PASS_FILE}" >/dev/null 2>&1; then
            echo "ERROR: The supplied password does not decrypt ${SECRETS_FILE}"
            echo "Please obtain the correct shared vault password and try again."
            exit 1
        fi
        echo "Vault password verified successfully"
    fi
fi

echo ""
setup_ansible_cfg
echo ""
encrypt_if_needed
echo ""
setup_gitignore
echo ""
echo "Setup complete"
echo ""
echo "Next steps:"
echo "1. Run your playbook:"
echo "   ansible-playbook playbooks/nexus-playbook.yml"
echo ""
echo "2. To edit secrets:"
echo "   ansible-vault edit ${SECRETS_FILE} --vault-id ${VAULT_ID}@${VAULT_PASS_FILE}"
echo ""
echo "Important: Never commit ${VAULT_PASS_FILE} to git"