#!/bin/bash
# ========================================
# Cloudflare Tunnel - Aplicar Melhorias HA
# ========================================
# 
# Este script aplica as melhorias de alta disponibilidade
# recomendadas pela comunidade Cloudflare.
#
# Mudanças:
# - 3 réplicas (de 1)
# - Health check ativo
# - Restart ilimitado
# - Zero-downtime updates
# - Métricas para Prometheus
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_NAME="gateway"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
BACKUP_FILE="${SCRIPT_DIR}/docker-compose.yml.backup-$(date +%Y%m%d-%H%M%S)"
IMPROVED_FILE="${SCRIPT_DIR}/docker-compose.yml.improved"

echo "=========================================="
echo "🛡️  Cloudflare Tunnel - HA Improvements"
echo "=========================================="
echo ""

# Verificar se está rodando como root ou com docker
if ! docker info > /dev/null 2>&1; then
    echo "❌ Erro: Docker não está acessível"
    echo "   Execute com 'sudo' ou adicione seu usuário ao grupo docker"
    exit 1
fi

# Verificar se arquivo improved existe
if [ ! -f "$IMPROVED_FILE" ]; then
    echo "❌ Erro: Arquivo $IMPROVED_FILE não encontrado"
    exit 1
fi

# Verificar se TUNNEL_TOKEN está definido
if [ -z "$TUNNEL_TOKEN" ]; then
    echo "⚠️  Aviso: TUNNEL_TOKEN não está definido no ambiente"
    echo "   Certifique-se de que está no arquivo .env ou exportado"
    echo ""
    read -p "   Continuar mesmo assim? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "📋 Status atual:"
echo ""
docker service ls --filter name=${STACK_NAME}_cloudflare 2>/dev/null || echo "   Serviço não encontrado"
echo ""

# Backup da configuração atual
echo "💾 Criando backup da configuração atual..."
if [ -f "$COMPOSE_FILE" ]; then
    cp "$COMPOSE_FILE" "$BACKUP_FILE"
    echo "   ✅ Backup salvo em: $BACKUP_FILE"
else
    echo "   ⚠️  Arquivo atual não encontrado, pulando backup"
fi
echo ""

# Mostrar diff
echo "📝 Mudanças que serão aplicadas:"
echo ""
if [ -f "$COMPOSE_FILE" ]; then
    diff -u "$COMPOSE_FILE" "$IMPROVED_FILE" | grep -E "^(\+|-)  " | head -20 || echo "   (muitas mudanças para exibir)"
else
    echo "   Nova configuração será criada"
fi
echo ""

read -p "🚀 Aplicar melhorias? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cancelado pelo usuário"
    exit 0
fi

# Aplicar nova configuração
echo ""
echo "🔄 Aplicando nova configuração..."
cp "$IMPROVED_FILE" "$COMPOSE_FILE"
echo "   ✅ Arquivo atualizado"

# Deploy do stack
echo ""
echo "🚀 Fazendo deploy do stack..."
cd "$SCRIPT_DIR"
docker stack deploy -c docker-compose.yml "$STACK_NAME"

echo ""
echo "⏳ Aguardando réplicas subirem..."
sleep 5

# Monitorar deploy
echo ""
echo "📊 Status das réplicas:"
echo ""

for i in {1..30}; do
    REPLICAS=$(docker service ls --filter name=${STACK_NAME}_cloudflare --format "{{.Replicas}}" 2>/dev/null || echo "0/0")
    echo "   [$i/30] Réplicas: $REPLICAS"
    
    if [[ "$REPLICAS" == "3/3" ]]; then
        echo ""
        echo "✅ Todas as réplicas estão UP!"
        break
    fi
    
    if [ $i -eq 30 ]; then
        echo ""
        echo "⚠️  Timeout aguardando réplicas. Verificando detalhes..."
        docker service ps ${STACK_NAME}_cloudflare-tunnel --no-trunc
        exit 1
    fi
    
    sleep 2
done

# Verificar saúde
echo ""
echo "🏥 Verificando health checks..."
sleep 10

docker service ps ${STACK_NAME}_cloudflare-tunnel --filter "desired-state=running" --format "table {{.Name}}\t{{.CurrentState}}" 2>/dev/null

# Teste de conectividade
echo ""
echo "🌐 Testando conectividade..."

if curl -sS -o /dev/null -w "HTTP %{http_code}" https://api.verlyvidracaria.com/verly-service/actuator/health 2>/dev/null; then
    echo " ✅ OK"
else
    echo " ⚠️  Falha - verificar manualmente"
fi

echo ""
echo "=========================================="
echo "✅ Melhorias aplicadas com sucesso!"
echo "=========================================="
echo ""
echo "📊 Próximos passos:"
echo ""
echo "1. Monitorar logs:"
echo "   docker service logs -f ${STACK_NAME}_cloudflare-tunnel"
echo ""
echo "2. Ver métricas:"
echo "   docker exec \$(docker ps -q -f name=cloudflare-tunnel) wget -qO- http://localhost:2000/metrics"
echo ""
echo "3. Configurar Prometheus (opcional):"
echo "   Adicione job 'cloudflared' no prometheus.yml"
echo "   Ver: /home/matt/CLOUDFLARE_TUNNEL_RESILIENCE_STRATEGY.md"
echo ""
echo "4. Dashboard Grafana (opcional):"
echo "   Import Dashboard ID: 17798"
echo ""
echo "📚 Documentação completa:"
echo "   cat /home/matt/CLOUDFLARE_TUNNEL_RESILIENCE_STRATEGY.md"
echo ""
echo "🔄 Para reverter:"
echo "   cp $BACKUP_FILE $COMPOSE_FILE"
echo "   docker stack deploy -c docker-compose.yml $STACK_NAME"
echo ""

