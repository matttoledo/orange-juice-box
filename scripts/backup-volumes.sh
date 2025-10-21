#!/bin/bash
set -e

# Orange Juice Box - Backup de Volumes
# Cria backup de todos os volumes críticos do Docker Swarm

BACKUP_BASE="/home/matt/backups/orange-juice-box"
BACKUP_DIR="$BACKUP_BASE/$(date +%Y-%m-%d_%H%M%S)"

echo "💾 Orange Juice Box - Backup de Volumes"
echo "Destino: $BACKUP_DIR"
echo ""

# Criar diretório de backup
mkdir -p "$BACKUP_DIR"

# Lista de volumes para backup
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

# Backup de cada volume
for name in "${!VOLUMES[@]}"; do
    volume="${VOLUMES[$name]}"

    echo "📦 Backing up: $name ($volume)..."

    # Verificar se volume existe
    if ! docker volume ls --format "{{.Name}}" | grep -q "^${volume}$"; then
        echo "⚠️  Volume $volume não encontrado, pulando..."
        continue
    fi

    # Fazer backup usando container temporário
    docker run --rm \
        -v "${volume}:/data:ro" \
        -v "$BACKUP_DIR:/backup" \
        ubuntu:22.04 \
        tar czf "/backup/${name}.tar.gz" /data

    # Verificar se backup foi criado
    if [ -f "$BACKUP_DIR/${name}.tar.gz" ]; then
        SIZE=$(du -h "$BACKUP_DIR/${name}.tar.gz" | cut -f1)
        echo "   ✅ $name.tar.gz ($SIZE)"
    else
        echo "   ❌ Falha ao criar backup de $name"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Backup completo!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📁 Localização: $BACKUP_DIR"
echo "📊 Tamanho total: $(du -sh "$BACKUP_DIR" | cut -f1)"
echo ""
echo "Arquivos:"
ls -lh "$BACKUP_DIR"
echo ""
echo "💡 Para restore:"
echo "   ./scripts/restore-volumes.sh $BACKUP_DIR"
