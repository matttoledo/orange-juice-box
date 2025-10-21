# Public Application Template

Template for applications **exposed to the internet** with **automatic full protection**.

## Automatic Protection

When you deploy using this template, your application automatically gets:

✅ **WAF (Coraza WASM)** - OWASP Core Rule Set protection
✅ **Rate Limiting** - 50 requests/min, burst 25
✅ **CrowdSec** - 17,000+ malicious IPs blocked
✅ **Security Headers** - HSTS, CSP, XSS Protection, Clickjacking prevention
✅ **Container Hardening** - OWASP Docker Top 10 compliant

## Quick Start

### 1. Copy Template
```bash
cd /home/matt/orange-juice-box/stacks/applications
cp -r _template-public my-new-api
cd my-new-api
```

### 2. Edit docker-compose.yml

Replace these placeholders:
- `my-app` → Your service name
- `my-app:latest` → Your Docker image
- `my-app.verlyvidracaria.com` → Your public domain
- `8080` → Your application port

### 3. Deploy
```bash
docker stack deploy -c docker-compose.yml my-new-api
```

### 4. Verify Protection
```bash
# Test WAF blocks XSS
curl "https://my-app.verlyvidracaria.com/?q=<script>alert('XSS')</script>"
# Expected: 403 Forbidden (blocked by WAF)

# Test rate limiting
for i in {1..60}; do
  curl -s -o /dev/null -w "%{http_code} " https://my-app.verlyvidracaria.com/health
done
# Expected: 200 (25x) → 429 (35x blocked)
```

## Security Flow

```
Internet
   ↓
WAF (Coraza)         ← Blocks: SQLi, XSS, RCE, LFI, Path Traversal
   ↓
Rate Limiting        ← Blocks: DDoS, abuse (50/min limit)
   ↓
CrowdSec             ← Blocks: Known malicious IPs (17,000+)
   ↓
Security Headers     ← Protects: XSS, Clickjacking, MIME sniffing
   ↓
Your Application     ← Clean, safe traffic only!
```

## When to Use This Template

Use this template when your application:
- ✅ Is accessible from the internet
- ✅ Has a public domain (e.g., api.example.com)
- ✅ Handles user data or sensitive operations
- ✅ Needs production-grade security

## Container Hardening Included

This template includes OWASP Docker Top 10 security:
- Non-root user (UID 1000)
- Read-only filesystem
- No capabilities
- No privilege escalation
- PID limits (prevents fork bombs)
- Resource limits (CPU, memory)

## Customization

### Add Database Connection
```yaml
networks:
  - postgresql_network    # Uncomment this

environment:
  - DATABASE_URL=postgresql://user:pass@postgresql:5432/db
```

### Add Prometheus Metrics
```yaml
networks:
  - monitoring_net        # Uncomment this

deploy:
  labels:
    - "metrics=/metrics"  # Add this
```

### Custom Health Check Path
```yaml
healthcheck:
  test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080/api/health"]
  # Change /api/health to your health endpoint
```

## Next Steps

1. Update your application to run as non-root user (UID 1000)
2. Ensure your app works with read-only filesystem (use /tmp for temp files)
3. Test locally before deploying
4. Monitor metrics in Grafana after deployment

## Support

- [Architecture Docs](../../../docs/architecture.md)
- [Security Layers](../../../docs/security-layers.md)
- [Adding Applications Guide](../../../docs/adding-applications.md)
