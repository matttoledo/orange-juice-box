#!/bin/bash
# Deploy Verly Service na Stack Applications

set -e

cd /home/matt/orange-juice-box/stacks/applications/verly-service

echo "=========================================="
echo "DEPLOY VERLY SERVICE - Stack Applications"
echo "=========================================="
echo ""

# Carregar variáveis do .env
if [ -f .env ]; then
    echo "Carregando variáveis do .env..."
    source .env
    echo "✅ Variáveis carregadas"
    echo "  VERLY_DB_USERNAME: $VERLY_DB_USERNAME"
    echo "  VERLY_DB_PASSWORD: ${VERLY_DB_PASSWORD:0:10}..."
else
    echo "⚠️  Arquivo .env não encontrado"
    exit 1
fi

echo ""
echo "Deployando stack applications..."
docker stack deploy -c docker-compose.yml applications

echo ""
echo "Aguardando inicialização do Spring Boot (90s)..."
sleep 90

echo ""
echo "Status do serviço:"
docker service ls | grep applications

echo ""
echo "Tasks:"
docker service ps applications_verly-service

echo ""
echo "✅ Deploy concluído!"
echo ""
echo "Próximos passos:"
echo "  1. Monitorar logs: docker service logs -f applications_verly-service"
echo "  2. Testar health: curl http://localhost:8080/verly-service/actuator/health"
echo "  3. Configurar proxy no NPM para api.verlyvidracaria.com"
