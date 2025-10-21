# 🔐 SOPS Guide - Secrets Management

## O que é SOPS?

**SOPS (Secrets OPerationS)** é uma ferramenta da Mozilla para criptografar secrets em arquivos de configuração.

### Por que usar SOPS?

✅ **Git-friendly**: Secrets criptografados podem ir pro Git com segurança
✅ **Auditoria completa**: Git history mostra quem mudou o quê
✅ **Diff legível**: Você vê qual chave mudou (valor fica criptografado)
✅ **Múltiplas chaves**: Suporta age, GPG, AWS KMS, Azure Key Vault
✅ **Integração Ansible**: Descriptografa automaticamente

---

## 🚀 Instalação

```bash
# Automático (Orange Juice Box)
make install-deps

# Ou manual:
./scripts/install-deps.sh
```

Instala:
- **age**: Sistema de criptografia (recomendado, mais simples que GPG)
- **SOPS**: Ferramenta de criptografia
- Versões ARM64 específicas

---

## 🔑 Setup Inicial

### 1. Gerar Chave age

```bash
./scripts/generate-secrets.sh
```

Isso cria:
- **Chave privada**: `~/.config/sops/age/keys.txt` (⚠️ NUNCA commit isso!)
- **Chave pública**: Mostrada no terminal (vai no `.sops.yaml`)

Saída exemplo:
```
Public key: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
```

### 2. Configurar .sops.yaml

Copie a chave pública e adicione ao `.sops.yaml`:

```yaml
creation_rules:
  - path_regex: ansible/group_vars/.*/secrets\.yml$
    age: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
```

### 3. Criar arquivo de secrets

```bash
cat > ansible/group_vars/production/secrets.yml << 'EOF'
# Secrets de Produção

# Traefik
traefik_auth: "admin:$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/"
acme_email: "admin@verlyvidracaria.com"

# CrowdSec
crowdsec_bouncer_key: "c1301faacfa39e0ed732fa14952ff524c8e3fb53ecea28c2ba454e6256c5933a"

# PostgreSQL
postgres_password: "sua_senha_super_secreta"
postgres_user: "verly"
postgres_db: "verly_production"

# Verly Service
jwt_secret: "sua_jwt_secret_key_muito_longa_e_segura"
spring_profiles_active: "production"

# Grafana
grafana_admin_password: "outra_senha_segura"

# AdGuard
adguard_admin_password: "senha_do_adguard"
EOF
```

### 4. Criptografar

```bash
sops -e -i ansible/group_vars/production/secrets.yml
```

Agora o arquivo está assim:
```yaml
traefik_auth: ENC[AES256_GCM,data:xR7vW...,iv:9Kl...,tag:Pm...]
acme_email: ENC[AES256_GCM,data:nF3pQ...,iv:kL8...,tag:Qw...]
```

**✅ Seguro para commit no Git!**

---

## ✏️ Editando Secrets

### Editar

```bash
sops ansible/group_vars/production/secrets.yml
```

O SOPS:
1. Descriptografa automaticamente
2. Abre no seu editor ($EDITOR)
3. Você edita normalmente
4. Ao salvar, SOPS criptografa novamente

### Exemplo de Edição

```bash
# Abrir editor
sops ansible/group_vars/production/secrets.yml

# Você vê (descriptografado temporariamente):
postgres_password: "senha_antiga"

# Muda para:
postgres_password: "senha_nova"

# Salva e fecha
# SOPS criptografa automaticamente ✅
```

### Ver Conteúdo (sem editar)

```bash
# Ver descriptografado no terminal
sops -d ansible/group_vars/production/secrets.yml

# Ver uma chave específica
sops -d --extract '["postgres_password"]' ansible/group_vars/production/secrets.yml
```

---

## 🔄 Workflow Típico

### Cenário: Trocar senha do PostgreSQL

```bash
# 1. Editar secret
sops ansible/group_vars/production/secrets.yml
# (Muda postgres_password no editor)

# 2. Commit
git add ansible/group_vars/production/secrets.yml
git commit -m "chore: atualizar senha PostgreSQL"
git push

# 3. Redeploy stack
make deploy STACK=postgresql

# SOPS descriptografa automaticamente durante deploy ✅
```

### Cenário: Adicionar novo secret

```bash
# 1. Editar
sops ansible/group_vars/production/secrets.yml

# 2. Adicionar linha:
redis_password: "nova_senha_redis"

# 3. Salvar e commit
git add ansible/group_vars/production/secrets.yml
git commit -m "feat: adicionar secret do Redis"
```

---

## 🔐 Integração com Ansible

SOPS é integrado automaticamente! Basta:

```yaml
# ansible/playbooks/deploy-stacks.yml
- name: Deploy PostgreSQL
  community.docker.docker_stack:
    name: postgresql
    compose:
      - "{{ stacks_base_path }}/postgresql/docker-compose.yml"
  environment:
    POSTGRES_PASSWORD: "{{ postgres_password }}"  # ← SOPS descriptografa!
```

O Ansible:
1. Detecta que `secrets.yml` está criptografado (SOPS)
2. Descriptografa automaticamente usando chave age
3. Usa o valor descriptografado
4. Nunca salva plain text no disco

---

## 🔄 Rotação de Secrets

### Rotacionar Senha

```bash
# 1. Editar
sops ansible/group_vars/production/secrets.yml

# 2. Mudar senha

# 3. Redeploy
make deploy STACK=postgresql

# 4. Atualizar senha no serviço também
# (Exemplo: PostgreSQL precisa ALTER USER)
```

### Rotacionar Chave SOPS

```bash
# 1. Gerar nova chave age
age-keygen -o ~/.config/sops/age/keys-new.txt

# 2. Adicionar ao .sops.yaml
# (manter chave antiga temporariamente)

# 3. Re-encriptar com nova chave
sops rotate ansible/group_vars/production/secrets.yml

# 4. Testar que funciona

# 5. Remover chave antiga do .sops.yaml
```

---

## 🚨 Troubleshooting

### "Failed to get the data key"

**Problema:** Chave age não encontrada

**Solução:**
```bash
# Verificar se chave existe
ls -la ~/.config/sops/age/keys.txt

# Verificar se SOPS_AGE_KEY_FILE está setado (opcional)
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt

# Ou usar --age-key diretamente
sops --age age1ql3z7... secrets.yml
```

### "No SOPS metadata found"

**Problema:** Arquivo não foi criptografado ainda

**Solução:**
```bash
# Criptografar arquivo
sops -e -i secrets.yml
```

### "MAC mismatch"

**Problema:** Arquivo corrompido ou chave errada

**Solução:**
```bash
# Usar chave correta
sops --age age1ql3z7... secrets.yml

# Se corrompido, restaurar do Git
git checkout HEAD -- secrets.yml
```

---

## 🎓 Exemplos Práticos

### Adicionar Secret do GitHub Actions

```bash
# 1. Editar
sops ansible/group_vars/production/secrets.yml

# 2. Adicionar:
github_token: "ghp_xxxxxxxxxxxxxx"

# 3. Usar no Ansible:
- name: Setup GitHub runner
  command: ./config.sh --token {{ github_token }}
```

### Secret com Múltiplas Linhas

```yaml
# Em SOPS, funciona normal:
ssh_private_key: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  b3BlbnNzaC1rZXktdjEAAAAA...
  -----END OPENSSH PRIVATE KEY-----
```

SOPS criptografa tudo, mantendo estrutura.

---

## 🔒 Segurança

### ✅ Boas Práticas

1. **Chave privada age**:
   - NUNCA commit `~/.config/sops/age/keys.txt`
   - Backup em local seguro (password manager, cofre)
   - Considerar ter backup em outro servidor

2. **Rotação**:
   - Rotacionar secrets regularmente (trimestral)
   - Rotacionar chave age anualmente

3. **Acesso**:
   - Apenas quem tem chave privada pode editar
   - Git history mostra quem editou (mas não o valor)

4. **CI/CD**:
   - Chave age em GitHub Secret (`SOPS_AGE_KEY`)
   - Nunca logar secrets descriptografados

### ❌ Evitar

- ❌ Commit chave privada age
- ❌ Compartilhar chave por email/chat
- ❌ Usar mesma chave para prod e dev
- ❌ Esquecer de criptografar após editar

---

## 📝 Comandos Úteis

```bash
# Editar
sops secrets.yml

# Ver descriptografado
sops -d secrets.yml

# Extrair uma chave
sops -d --extract '["postgres_password"]' secrets.yml

# Criptografar arquivo
sops -e -i secrets.yml

# Descriptografar para arquivo
sops -d secrets.yml > secrets.plain.yml

# Rotacionar chaves
sops rotate -i secrets.yml

# Verificar integridade
sops -d secrets.yml > /dev/null && echo "OK"
```

---

## 🆚 Alternativas

| Ferramenta | Prós | Contras |
|------------|------|---------|
| **SOPS** | Git-friendly, diff legível | Precisa chave separada |
| **Ansible Vault** | Integrado ao Ansible | Diff ilegível (arquivo todo criptografado) |
| **Git-crypt** | Transparente | Criptografa arquivo todo |
| **HashiCorp Vault** | Enterprise-grade | Complexo, precisa servidor |
| **Docker Secrets** | Nativo do Swarm | Apenas runtime, não versionado |

**Escolhemos SOPS** por ser:
- ✅ Git-friendly
- ✅ Diff legível (vê qual chave mudou)
- ✅ Integração Ansible
- ✅ Simples de usar

---

## 📚 Referências

- [SOPS GitHub](https://github.com/getsops/sops)
- [age Encryption](https://github.com/FiloSottile/age)
- [Ansible + SOPS](https://ansible.readthedocs.io/projects/lint/rules/yaml/)

---

**Orange Juice Box** 🍊 - Secrets seguros, infraestrutura confiável!
