#!/bin/bash
set -e

# ========================================
# Orange Juice Box - Deploy Specific Layer
# ========================================
# Deploys a specific infrastructure layer
#
# Usage: ./scripts/deploy-layer.sh <layer>
#
# Layers:
#   security        - Traefik, CrowdSec, WAF
#   infrastructure  - PostgreSQL, Redis
#   observability   - Grafana, Prometheus, Redash, Dozzle, Portainer
#   applications    - Verly Service (and other apps)
#
# Example: ./scripts/deploy-layer.sh security
#
# ========================================

LAYER=$1
ORANGE_JUICE_BOX_DIR="/home/matt/orange-juice-box"

if [ -z "$LAYER" ]; then
  echo "❌ Error: Layer not specified"
  echo ""
  echo "Usage: $0 <layer>"
  echo ""
  echo "Available layers:"
  echo "  security        - Traefik, CrowdSec, WAF"
  echo "  infrastructure  - PostgreSQL, Redis"
  echo "  observability   - Grafana, Prometheus, Redash, Dozzle, Portainer"
  echo "  applications    - Verly Service (and other apps)"
  echo ""
  exit 1
fi

LAYER_DIR="${ORANGE_JUICE_BOX_DIR}/stacks/${LAYER}"

if [ ! -d "$LAYER_DIR" ]; then
  echo "❌ Error: Layer directory not found: $LAYER_DIR"
  exit 1
fi

echo "🚀 Deploying layer: ${LAYER}"
echo "   Directory: ${LAYER_DIR}"
echo ""

cd "$LAYER_DIR"

# Special handling for security layer (needs CROWDSEC_BOUNCER_KEY)
if [ "$LAYER" == "security" ]; then
  if [ -f .env ]; then
    export $(cat .env | grep CROWDSEC_BOUNCER_KEY | xargs)
  fi

  if [ -z "$CROWDSEC_BOUNCER_KEY" ]; then
    echo "⚠️  WARNING: CROWDSEC_BOUNCER_KEY not set"
    echo "   CrowdSec bouncer may fail to start"
    echo ""
  fi
fi

# Special handling for applications layer (multiple stacks)
if [ "$LAYER" == "applications" ]; then
  echo "📦 Deploying all application stacks..."

  for app_dir in */; do
    # Skip template directories
    if [[ "$app_dir" == _* ]]; then
      continue
    fi

    app_name="${app_dir%/}"
    echo "   → Deploying: $app_name"

    cd "$app_dir"
    docker stack deploy -c docker-compose.yml "$app_name" --prune
    cd ..
  done

  echo "✅ All application stacks deployed"
else
  # Deploy single stack
  docker stack deploy -c docker-compose.yml "${LAYER}" --prune
  echo "✅ Layer '${LAYER}' deployed successfully"
fi

echo ""
echo "📊 Services in ${LAYER}:"
docker service ls | grep "${LAYER}_" || echo "   No services found (check stack name)"

echo ""
echo "✅ Done!"
