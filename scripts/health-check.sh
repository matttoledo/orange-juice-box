#!/bin/bash
set -e

echo "🏥 Orange Juice Box - Health Check"
echo ""

# Lista de serviços críticos
SERVICES=(
    "security_traefik"
    "security_crowdsec"
    "security_bouncer-traefik"
    "verly_verly-service"
    "postgresql_postgresql"
    "swarm-monitoring_grafana"
    "swarm-monitoring_prometheus"
    "swarm-monitoring_cadvisor"
    "swarm-monitoring_node-exporter"
    "adguard_adguard"
    "portainer"
    "alertmanager"
    "dozzle"
)

FAILURES=0
WARNINGS=0

# Verificar cada serviço
for service in "${SERVICES[@]}"; do
    # Verificar se serviço existe
    if ! docker service ls --format "{{.Name}}" | grep -q "^${service}$"; then
        echo "⚠️  $service: não encontrado (pode não estar deployado)"
        ((WARNINGS++))
        continue
    fi

    # Verificar estado
    STATUS=$(docker service ps "$service" --filter "desired-state=running" --format "{{.CurrentState}}" 2>/dev/null | head -1)

    if echo "$STATUS" | grep -q "Running"; then
        # Verificar há quanto tempo está rodando
        UPTIME=$(echo "$STATUS" | grep -o "Running.*" | sed 's/Running //')
        echo "✅ $service ($UPTIME)"
    elif echo "$STATUS" | grep -q "Starting"; then
        echo "🔄 $service: iniciando..."
        ((WARNINGS++))
    else
        echo "❌ $service: $STATUS"
        ((FAILURES++))
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Resumo:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Serviços verificados: ${#SERVICES[@]}"
echo "   ✅ Saudáveis: $((${#SERVICES[@]} - FAILURES - WARNINGS))"
echo "   ⚠️  Avisos: $WARNINGS"
echo "   ❌ Falhas: $FAILURES"
echo ""

if [ $FAILURES -eq 0 ]; then
    if [ $WARNINGS -eq 0 ]; then
        echo "🍊 Orange Juice Box is healthy! Tudo funcionando perfeitamente!"
        exit 0
    else
        echo "🍊 Orange Juice Box is mostly healthy, mas com $WARNINGS aviso(s)."
        exit 0
    fi
else
    echo "❌ Orange Juice Box has $FAILURES service(s) unhealthy!"
    echo ""
    echo "Ver logs:"
    echo "  docker service logs <service_name>"
    exit 1
fi
