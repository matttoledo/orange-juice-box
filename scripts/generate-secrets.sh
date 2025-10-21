#!/bin/bash
set -e

echo "🔐 Orange Juice Box - Setup SOPS"
echo ""

# Verificar se SOPS está instalado
if ! command -v sops &> /dev/null; then
    echo "❌ SOPS não encontrado!"
    echo "   Execute: make install-deps"
    exit 1
fi

if ! command -v age &> /dev/null; then
    echo "❌ age não encontrado!"
    echo "   Execute: make install-deps"
    exit 1
fi

# Criar diretório para chaves age
mkdir -p ~/.config/sops/age

# Gerar chave age
if [ -f ~/.config/sops/age/keys.txt ]; then
    echo "⚠️  Chave age já existe em ~/.config/sops/age/keys.txt"
    echo ""
    read -p "Gerar nova chave? (isso vai SOBRESCREVER a antiga) [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Cancelado. Usando chave existente."
    else
        age-keygen -o ~/.config/sops/age/keys.txt
        echo "✅ Nova chave age gerada!"
    fi
else
    age-keygen -o ~/.config/sops/age/keys.txt
    echo "✅ Chave age gerada!"
fi

# Extrair public key
AGE_PUBLIC_KEY=$(grep "public key:" ~/.config/sops/age/keys.txt | cut -d: -f2 | tr -d ' ')

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 COPIE E COLE NO .sops.yaml:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
cat << EOF
creation_rules:
  - path_regex: ansible/group_vars/.*/secrets\\.yml$
    age: $AGE_PUBLIC_KEY
  - path_regex: .*\\.env\\.encrypted$
    age: $AGE_PUBLIC_KEY
EOF
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Criar .sops.yaml automaticamente
if [ ! -f .sops.yaml ]; then
    cat > .sops.yaml << EOF
creation_rules:
  - path_regex: ansible/group_vars/.*/secrets\\.yml\$
    age: $AGE_PUBLIC_KEY
  - path_regex: .*\\.env\\.encrypted\$
    age: $AGE_PUBLIC_KEY
EOF
    echo ""
    echo "✅ Arquivo .sops.yaml criado automaticamente!"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚠️  IMPORTANTE - SALVE A CHAVE PRIVADA!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Localização: ~/.config/sops/age/keys.txt"
echo ""
echo "Faça backup desta chave em local seguro!"
echo "  - Password manager"
echo "  - Cofre físico"
echo "  - Outro servidor"
echo ""
echo "SEM ESTA CHAVE VOCÊ NÃO CONSEGUE EDITAR OS SECRETS!"
echo ""

# Criar template de secrets se não existir
SECRETS_FILE="ansible/group_vars/production/secrets.yml"
if [ ! -f "$SECRETS_FILE" ]; then
    mkdir -p ansible/group_vars/production

    cat > "$SECRETS_FILE" << 'EOF'
# 🔐 Secrets de Produção - Orange Juice Box
# Este arquivo será criptografado com SOPS

# Traefik
traefik_auth: "admin:$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/"  # Gerar: htpasswd -nb admin senha
acme_email: "admin@seudominio.com"

# CrowdSec
crowdsec_bouncer_key: "CHANGE_ME_32_CHARS_RANDOM"

# PostgreSQL
postgres_password: "CHANGE_ME_STRONG_PASSWORD"
postgres_user: "appuser"
postgres_db: "app_production"

# Aplicação
jwt_secret: "CHANGE_ME_VERY_LONG_RANDOM_SECRET_KEY"
spring_profiles_active: "production"

# Grafana
grafana_admin_password: "CHANGE_ME"

# AdGuard
adguard_admin_password: "CHANGE_ME"
EOF

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📝 Próximos passos:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1. Editar secrets:"
    echo "   sops $SECRETS_FILE"
    echo ""
    echo "2. Trocar CHANGE_ME por valores reais"
    echo ""
    echo "3. Salvar e fechar editor"
    echo "   SOPS vai criptografar automaticamente ✅"
    echo ""
    echo "4. Commit (arquivo estará criptografado):"
    echo "   git add $SECRETS_FILE .sops.yaml"
    echo "   git commit -m 'Add encrypted secrets'"
    echo ""
else
    echo ""
    echo "📝 Secrets já existem em: $SECRETS_FILE"
    echo ""
    echo "Para editar:"
    echo "  sops $SECRETS_FILE"
fi
