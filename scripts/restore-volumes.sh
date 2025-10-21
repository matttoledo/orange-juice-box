#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "❌ Uso: $0 /path/to/backup/directory"
    echo ""
    echo "Exemplo:"
    echo "  $0 /home/matt/backups/orange-juice-box/2025-10-19_030000"
    exit 1
fi

BACKUP_DIR="$1"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ Diretório não encontrado: $BACKUP_DIR"
    exit 1
fi

echo "🔄 Orange Juice Box - Restore de Volumes"
echo "Origem: $BACKUP_DIR"
echo ""

# Lista de volumes
declare -A VOLUMES=(
    ["postgresql_data"]="postgresql_postgresql_data"
    ["traefik_acme"]="security_traefik_acme"
    ["grafana_data"]="swarm-monitoring_grafana-data"
    ["prometheus_data"]="swarm-monitoring_prometheus-data"
    ["crowdsec_config"]="security_crowdsec_config"
    ["crowdsec_data"]="security_crowdsec_data"
    ["crowdsec_dashboard"]="security_crowdsec_dashboard"
    ["adguard_config"]="adguard_adguard_config"
    ["adguard_work"]="adguard_adguard_work"
    ["portainer_data"]="portainer_data"
)

echo "⚠️  ATENÇÃO: Restore vai SOBRESCREVER dados atuais!"
echo ""
read -p "Continuar? [y/N]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cancelado."
    exit 0
fi

echo ""

# Restore de cada volume
for name in "${!VOLUMES[@]}"; do
    volume="${VOLUMES[$name]}"
    backup_file="$BACKUP_DIR/${name}.tar.gz"

    if [ ! -f "$backup_file" ]; then
        echo "⚠️  Backup não encontrado: ${name}.tar.gz, pulando..."
        continue
    fi

    echo "📦 Restoring: $name ($volume)..."

    # Criar volume se não existir
    docker volume create "$volume" 2>/dev/null || true

    # Restore usando container temporário
    docker run --rm \
        -v "${volume}:/data" \
        -v "$BACKUP_DIR:/backup:ro" \
        ubuntu:22.04 \
        bash -c "cd /data && tar xzf /backup/${name}.tar.gz --strip-components=1"

    echo "   ✅ $name restaurado"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Restore completo!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🔄 Próximo passo: Reiniciar serviços"
echo "   make deploy-all"
