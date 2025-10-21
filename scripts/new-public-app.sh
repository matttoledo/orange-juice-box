#!/bin/bash
set -e

# ========================================
# Orange Juice Box - Create New Public App
# ========================================
# Creates a new public application from template with automatic protection
#
# Usage: ./scripts/new-public-app.sh <name> <domain> <port>
#
# Example: ./scripts/new-public-app.sh my-api my-api.verlyvidracaria.com 8080
#
# Automatic Protection:
#   ✅ WAF (Coraza WASM - OWASP CRS)
#   ✅ Rate Limiting (50/min)
#   ✅ CrowdSec (17,000+ IPs)
#   ✅ Security Headers (HSTS, CSP, XSS)
#   ✅ Container Hardening (OWASP)
#
# ========================================

APP_NAME=$1
DOMAIN=$2
PORT=$3

if [ -z "$APP_NAME" ] || [ -z "$DOMAIN" ] || [ -z "$PORT" ]; then
  echo "❌ Error: Missing arguments"
  echo ""
  echo "Usage: $0 <app-name> <domain> <port>"
  echo ""
  echo "Arguments:"
  echo "  app-name   Name of the application (lowercase, no spaces)"
  echo "  domain     Public domain (e.g., api.example.com)"
  echo "  port       Application port (e.g., 8080)"
  echo ""
  echo "Example:"
  echo "  $0 my-api my-api.verlyvidracaria.com 8080"
  echo ""
  exit 1
fi

TEMPLATE_DIR="/home/matt/orange-juice-box/stacks/applications/_template-public"
TARGET_DIR="/home/matt/orange-juice-box/stacks/applications/${APP_NAME}"

if [ -d "$TARGET_DIR" ]; then
  echo "❌ Error: Application already exists: ${TARGET_DIR}"
  echo "   Remove it first or choose a different name"
  exit 1
fi

echo "🚀 Creating new public application: ${APP_NAME}"
echo "   Domain: ${DOMAIN}"
echo "   Port: ${PORT}"
echo ""

# Copy template
echo "📋 Copying template..."
cp -r "$TEMPLATE_DIR" "$TARGET_DIR"

# Replace placeholders
echo "✏️  Updating configuration..."
cd "$TARGET_DIR"

sed -i "s/my-app/${APP_NAME}/g" docker-compose.yml
sed -i "s/my-app.verlyvidracaria.com/${DOMAIN}/g" docker-compose.yml
sed -i "s/8080/${PORT}/g" docker-compose.yml

echo ""
echo "=========================================="
echo "✅ Public application created successfully!"
echo "=========================================="
echo ""
echo "📁 Location: ${TARGET_DIR}"
echo "🌐 Domain: ${DOMAIN}"
echo "🔌 Port: ${PORT}"
echo ""
echo "🛡️  Automatic Protection:"
echo "   ✅ WAF (Coraza WASM - OWASP CRS)"
echo "   ✅ Rate Limiting (50 req/min)"
echo "   ✅ CrowdSec (17,000+ blocked IPs)"
echo "   ✅ Security Headers (HSTS, CSP, XSS)"
echo "   ✅ Container Hardening (OWASP Docker Top 10)"
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
echo "   3. Test protection:"
echo "      curl \"https://${DOMAIN}/?q=<script>alert('XSS')</script>\""
echo "      # Should return: 403 Forbidden (blocked by WAF)"
echo ""
echo "   4. Monitor:"
echo "      Check Portainer: http://portainer.192.168.0.2.nip.io"
echo "      Check Grafana: http://grafana.192.168.0.2.nip.io"
echo ""
echo "🎉 Your new app is ready to deploy with full protection!"
