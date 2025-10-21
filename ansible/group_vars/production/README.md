# Production Secrets

This directory contains SOPS-encrypted secrets for the production environment.

## Prerequisites

1. **age** and **SOPS** installed
2. age key configured in `~/.config/sops/age/keys.txt`

## How to Use

### View secrets (decrypt temporarily)
```bash
sops --decrypt secrets.yml
```

### Edit secrets
```bash
sops secrets.yml
```
This will open the decrypted file in your editor. When saved, it will be automatically re-encrypted.

### Add new secret
```bash
sops secrets.yml
# Add the new line
# Save and close
```

## Using Secrets in Ansible

Secrets are automatically decrypted during playbook execution:

```yaml
# In playbook or docker-compose
environment:
  - SPRING_DATASOURCE_PASSWORD={{ verly_db_password }}
```

## Backup age Key

⚠️ **IMPORTANT**: Backup your age private key!

```bash
cp ~/.config/sops/age/keys.txt ~/secure-backup/age-keys-backup.txt
```

Without the private key, you won't be able to decrypt the secrets!

## age Public Key

```
age1lp0mjc900vahqvuyg6dr45vcpu03pddljspkhw6pppj8k5vp49kqynk9nq
```

This public key is configured in `.sops.yaml` at the repository root.
