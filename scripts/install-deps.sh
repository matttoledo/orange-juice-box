#!/bin/bash
set -e

echo "🍊 Orange Juice Box - Instalando dependências..."
echo ""

# Verificar se é ARM64
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
    echo "⚠️  Atenção: Este script é otimizado para ARM64/aarch64"
    echo "   Arquitetura detectada: $ARCH"
    echo ""
fi

# Install age (sistema de criptografia para SOPS)
echo "📦 Instalando age..."
if command -v age &> /dev/null; then
    echo "✅ age já instalado: $(age --version)"
else
    wget -q https://github.com/FiloSottile/age/releases/download/v1.1.1/age-v1.1.1-linux-arm64.tar.gz
    tar xf age-*.tar.gz
    sudo mv age/age age/age-keygen /usr/local/bin/
    rm -rf age age-*.tar.gz
    echo "✅ age instalado!"
fi

# Install SOPS
echo "📦 Instalando SOPS..."
if command -v sops &> /dev/null; then
    echo "✅ SOPS já instalado: $(sops --version)"
else
    wget -q https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.arm64
    sudo mv sops-*.arm64 /usr/local/bin/sops
    sudo chmod +x /usr/local/bin/sops
    echo "✅ SOPS instalado!"
fi

# Install Ansible
echo "📦 Instalando Ansible..."
if command -v ansible &> /dev/null; then
    echo "✅ Ansible já instalado: $(ansible --version | head -1)"
else
    sudo apt update
    sudo apt install -y python3-pip
    pip3 install ansible ansible-core
    echo "✅ Ansible instalado!"
fi

# Install community.docker collection
echo "📦 Instalando Ansible community.docker..."
ansible-galaxy collection install community.docker --force

# Verificar instalações
echo ""
echo "✅ Dependências instaladas com sucesso!"
echo ""
echo "Versões:"
sops --version
echo "age: $(age --version)"
ansible --version | head -1

echo ""
echo "🎯 Próximos passos:"
echo "  1. ./scripts/generate-secrets.sh    # Gerar chave SOPS"
echo "  2. make setup                        # Setup infraestrutura"
echo "  3. make deploy-all                   # Deploy stacks"
