# Internal Application Template

Template for applications accessible **ONLY from LAN** (dashboards, admin tools).

## Protection Strategy

Internal apps have **ZERO middlewares** for maximum simplicity and performance.

Protection comes from:
- ✅ **UFW Firewall** - Blocks external access to internal ports
- ✅ **Traefik Routing** - Only responds to `.nip.io` domains (not public)
- ✅ **Network Segmentation** - Docker overlay networks
- ✅ **Physical Security** - LAN is physically controlled

NO overhead, NO complexity, maximum speed! ⚡

## Quick Start

### 1. Copy Template
```bash
cd /home/matt/orange-juice-box/stacks/applications
cp -r _template-internal my-dashboard
cd my-dashboard
```

### 2. Edit docker-compose.yml

Replace these placeholders:
- `my-dashboard` → Your service name
- `my-dashboard:latest` → Your Docker image
- `3000` → Your application port

### 3. Deploy
```bash
docker stack deploy -c docker-compose.yml my-dashboard
```

### 4. Access
```bash
# LAN access only
open http://my-dashboard.192.168.0.2.nip.io
```

## Security Flow

```
LAN Device (192.168.0.x)
   ↓
Traefik Router          ← Only accepts .nip.io domains
   ↓
Your Application        ← Direct access (no middlewares!)
```

**External Access:**
```
Internet
   ↓
UFW Firewall            ← BLOCKS (port not exposed)
   ✖️ Access denied
```

## When to Use This Template

Use this template when your application:
- ✅ Is a dashboard or admin tool
- ✅ Should only be accessible from LAN
- ✅ Doesn't need rate limiting (trusted users)
- ✅ Doesn't need WAF (not exposed to threats)

Examples:
- Grafana
- Prometheus
- Redash
- Portainer
- Dozzle
- pgAdmin
- Redis Commander

## Performance

Internal apps are **FAST** because:
- No WAF processing (~0ms overhead)
- No rate limit checks (~0ms overhead)
- No CrowdSec API calls (~0ms overhead)
- No security headers added (~0ms overhead)

Total middleware overhead: **0ms** ⚡

## Optional: Add Authentication

If you want to add basic auth:

```yaml
labels:
  # Add this middleware
  - "traefik.http.routers.my-dashboard.middlewares=basic-auth@file"
```

Then create in security stack:
```yaml
# security/traefik/dynamic/auth.yml
http:
  middlewares:
    basic-auth:
      basicAuth:
        users:
          - "admin:$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/"
```

## Customization

### Add Database Connection
```yaml
networks:
  - postgresql_network    # Uncomment this

environment:
  - DATABASE_URL=postgresql://user:pass@postgresql:5432/db
```

### Change Domain
```yaml
# Use different local domain
- "traefik.http.routers.my-dashboard.rule=Host(`dashboard.local`)"

# Add to /etc/hosts:
# 192.168.0.2  dashboard.local
```

## Next Steps

1. Configure your application
2. Deploy to swarm
3. Access from LAN browser
4. Enjoy fast, simple, secure internal tooling!

## Support

- [Architecture Docs](../../../docs/architecture.md)
- [Adding Applications Guide](../../../docs/adding-applications.md)
