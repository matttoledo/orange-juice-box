# Production Secrets

Este diretório contém secrets criptografados com SOPS para o ambiente de produção.

## Pré-requisitos

1. **age** e **SOPS** instalados
2. Chave age configurada em `~/.config/sops/age/keys.txt`

## Como usar

### Ver secrets (descriptografar temporariamente)
```bash
sops --decrypt secrets.yml
```

### Editar secrets
```bash
sops secrets.yml
```
Isso abrirá o arquivo descriptografado no seu editor. Ao salvar, será automaticamente re-criptografado.

### Adicionar novo secret
```bash
sops secrets.yml
# Adicione a nova linha
# Salve e feche
```

## Usando secrets no Ansible

Os secrets são automaticamente descriptografados durante a execução do playbook:

```yaml
# No playbook ou docker-compose
environment:
  - SPRING_DATASOURCE_PASSWORD={{ verly_db_password }}
```

## Backup da chave age

⚠️ **IMPORTANTE**: Faça backup da sua chave age privada!

```bash
cp ~/.config/sops/age/keys.txt ~/backup-seguro/age-keys-backup.txt
```

Sem a chave privada, você não conseguirá descriptografar os secrets!

## Chave pública age

```
age1lp0mjc900vahqvuyg6dr45vcpu03pddljspkhw6pppj8k5vp49kqynk9nq
```

Esta chave pública está configurada em `.sops.yaml` na raiz do repositório.
