#!/bin/bash
set -e

# ========================================
# Orange Juice Box - Create New Internal App
# ========================================
# Creates a new internal application (LAN-only) from template
#
# Usage: ./scripts/new-internal-app.sh <name> <port>
#
# Example: ./scripts/new-internal-app.sh my-dashboard 3000
#
# Protection:
#   ❌ NO WAF (not exposed to internet)
#   ❌ NO Rate Limiting (trusted LAN)
#   ❌ NO CrowdSec (LAN is trusted)
#   ❌ NO Security Headers (unnecessary overhead)
#   ✅ UFW Firewall (blocks external access)
#
# ========================================

APP_NAME=$1
PORT=$2

if [ -z "$APP_NAME" ] || [ -z "$PORT" ]; then
  echo "❌ Error: Missing arguments"
  echo ""
  echo "Usage: $0 <app-name> <port>"
  echo ""
  echo "Arguments:"
  echo "  app-name   Name of the application (lowercase, no spaces)"
  echo "  port       Application port (e.g., 3000)"
  echo ""
  echo "Example:"
  echo "  $0 my-dashboard 3000"
  echo ""
  exit 1
fi

TEMPLATE_DIR="/home/matt/orange-juice-box/stacks/applications/_template-internal"
TARGET_DIR="/home/matt/orange-juice-box/stacks/applications/${APP_NAME}"

if [ -d "$TARGET_DIR" ]; then
  echo "❌ Error: Application already exists: ${TARGET_DIR}"
  echo "   Remove it first or choose a different name"
  exit 1
fi

echo "📊 Creating new internal application: ${APP_NAME}"
echo "   Port: ${PORT}"
echo "   Access: LAN only (http://${APP_NAME}.192.168.0.2.nip.io)"
echo ""

# Copy template
echo "📋 Copying template..."
cp -r "$TEMPLATE_DIR" "$TARGET_DIR"

# Replace placeholders
echo "✏️  Updating configuration..."
cd "$TARGET_DIR"

sed -i "s/my-dashboard/${APP_NAME}/g" docker-compose.yml
sed -i "s/3000/${PORT}/g" docker-compose.yml

echo ""
echo "=========================================="
echo "✅ Internal application created successfully!"
echo "=========================================="
echo ""
echo "📁 Location: ${TARGET_DIR}"
echo "🌐 Access: http://${APP_NAME}.192.168.0.2.nip.io (LAN only)"
echo "🔌 Port: ${PORT}"
echo ""
echo "🛡️  Protection Strategy:"
echo "   ✅ UFW Firewall (blocks external access)"
echo "   ✅ Traefik routing (.nip.io domain restriction)"
echo "   ❌ NO WAF (not needed for LAN)"
echo "   ❌ NO Rate Limiting (trusted network)"
echo "   ❌ NO Middlewares (maximum performance!)"
echo ""
echo "📝 Next Steps:"
echo "   1. Edit docker-compose.yml:"
echo "      cd ${TARGET_DIR}"
echo "      vim docker-compose.yml"
echo "      # Update: image, environment variables"
echo ""
echo "   2. Deploy:"
echo "      docker stack deploy -c docker-compose.yml ${APP_NAME}"
echo ""
echo "   3. Access from LAN:"
echo "      open http://${APP_NAME}.192.168.0.2.nip.io"
echo ""
echo "   4. Monitor:"
echo "      Check Portainer: http://portainer.192.168.0.2.nip.io"
echo ""
echo "⚡ Your internal app is ready - fast and simple!"
