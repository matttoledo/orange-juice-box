#!/bin/bash
set -e

# ========================================
# Orange Juice Box - Deploy All Layers
# ========================================
# Deploys all infrastructure layers in the correct order
#
# Usage: ./scripts/deploy-all.sh
#
# ========================================

ORANGE_JUICE_BOX_DIR="/home/matt/orange-juice-box"

echo "🍊 Orange Juice Box - Deploying All Layers"
echo "=========================================="
echo ""

# ========================================
# Layer 1: Security
# ========================================
echo "🛡️  Layer 1: Security (Traefik, CrowdSec, WAF)"
echo "   Deploying security stack..."

cd "${ORANGE_JUICE_BOX_DIR}/stacks/security"

# Load CROWDSEC_BOUNCER_KEY from .env
if [ -f .env ]; then
  export $(cat .env | grep CROWDSEC_BOUNCER_KEY | xargs)
fi

if [ -z "$CROWDSEC_BOUNCER_KEY" ]; then
  echo "   ⚠️  WARNING: CROWDSEC_BOUNCER_KEY not set!"
  echo "   CrowdSec bouncer may fail to start."
fi

docker stack deploy -c docker-compose.yml security --prune

echo "   ✅ Security stack deployed"
echo "   ⏳ Waiting for Traefik to be ready (15s)..."
sleep 15
echo ""

# ========================================
# Layer 2: Infrastructure
# ========================================
echo "🗄️  Layer 2: Infrastructure (PostgreSQL, Redis)"
echo "   Deploying infrastructure stack..."

cd "${ORANGE_JUICE_BOX_DIR}/stacks/infrastructure"
docker stack deploy -c docker-compose.yml infrastructure --prune

echo "   ✅ Infrastructure stack deployed"
echo "   ⏳ Waiting for PostgreSQL to be ready (10s)..."
sleep 10
echo ""

# ========================================
# Layer 3: Observability
# ========================================
echo "📊 Layer 3: Observability (Grafana, Prometheus, Redash, Dozzle, Portainer)"
echo "   Deploying observability stack..."

cd "${ORANGE_JUICE_BOX_DIR}/stacks/observability"
docker stack deploy -c docker-compose.yml observability --prune

echo "   ✅ Observability stack deployed"
echo "   ⏳ Waiting for services to initialize (10s)..."
sleep 10
echo ""

# ========================================
# Layer 4: Applications
# ========================================
echo "🚀 Layer 4: Applications (Verly Service)"
echo "   Deploying application stacks..."

cd "${ORANGE_JUICE_BOX_DIR}/stacks/applications/verly-service"
docker stack deploy -c docker-compose.yml verly --prune

echo "   ✅ Application stacks deployed"
echo ""

# ========================================
# Summary
# ========================================
echo "=========================================="
echo "✅ All layers deployed successfully!"
echo "=========================================="
echo ""

echo "📊 Services Status:"
docker service ls

echo ""
echo "🌐 Access Points:"
echo "   • Verly Service (Public):  https://api.verlyvidracaria.com"
echo "   • Grafana (LAN):           http://grafana.192.168.0.2.nip.io"
echo "   • Prometheus (LAN):        http://prometheus.192.168.0.2.nip.io"
echo "   • Redash (LAN):            http://redash.192.168.0.2.nip.io"
echo "   • Dozzle (LAN):            http://dozzle.192.168.0.2.nip.io"
echo "   • Portainer (LAN):         http://portainer.192.168.0.2.nip.io"
echo ""

echo "🛡️  Security Status:"
echo "   • Public apps:    WAF + Rate Limit (50/min) + CrowdSec + Headers"
echo "   • Internal apps:  No middlewares (firewall protection only)"
echo ""

echo "🎉 Orange Juice Box is ready!"
