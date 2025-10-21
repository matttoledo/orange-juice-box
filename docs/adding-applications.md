# Adding Applications to Orange Juice Box

Quick guide to deploy new applications with automatic protection.

---

## Option 1: Public Application (Internet-facing)

For APIs, web services, or any application exposed to the internet.

### Automatic Protection

Your app automatically gets:
- ✅ WAF (Coraza WASM - OWASP CRS)
- ✅ Rate Limiting (50/min, burst 25)
- ✅ CrowdSec (17,000+ blocked IPs)
- ✅ Security Headers (HSTS, CSP, XSS)
- ✅ Container Hardening (OWASP Docker Top 10)

### Quick Start

```bash
# 1. Create from template
./scripts/new-public-app.sh my-api my-api.verlyvidracaria.com 8080

# 2. Edit configuration
cd stacks/applications/my-api
vim docker-compose.yml

# Update:
#   - image: your-app:latest
#   - environment variables
#   - health check path
#   - resource limits (if needed)

# 3. Deploy
docker stack deploy -c docker-compose.yml my-api

# 4. Test protection
curl "https://my-api.verlyvidracaria.com/?q=<script>alert('XSS')</script>"
# Should return: 403 Forbidden (blocked by WAF)

# 5. Monitor
open http://portainer.192.168.0.2.nip.io
open http://grafana.192.168.0.2.nip.io
```

### What You Need to Configure

**Minimal (required):**
1. Docker image name
2. Public domain
3. Application port

**Optional:**
4. Environment variables
5. Database connection (if needed)
6. Resource limits (defaults are usually fine)
7. Health check endpoint

That's it! Protection is automatic.

---

## Option 2: Internal Application (LAN-only)

For dashboards, admin tools, or internal services.

### Protection Strategy

- ✅ UFW Firewall (blocks external access)
- ✅ Traefik routing (.nip.io domains only)
- ❌ NO WAF, NO Rate Limiting, NO Middlewares

**Result:** Maximum simplicity and performance!

### Quick Start

```bash
# 1. Create from template
./scripts/new-internal-app.sh my-dashboard 3000

# 2. Edit configuration
cd stacks/applications/my-dashboard
vim docker-compose.yml

# Update:
#   - image: your-dashboard:latest
#   - environment variables
#   - port (if not 3000)

# 3. Deploy
docker stack deploy -c docker-compose.yml my-dashboard

# 4. Access (LAN only)
open http://my-dashboard.192.168.0.2.nip.io
```

---

## Adding Database Connection

If your application needs PostgreSQL:

```yaml
networks:
  - postgresql_network    # Add this network

environment:
  - DATABASE_URL=postgresql://user:${DB_PASSWORD}@postgresql:5432/your_db
  - DB_HOST=postgresql
  - DB_PORT=5432
  - DB_NAME=your_db
  - DB_USER=your_user
  - DB_PASSWORD=${DB_PASSWORD}  # From SOPS secrets
```

**Create database:**
```sql
-- Add to stacks/infrastructure/postgresql/init-scripts/02-your-app-db.sql
CREATE DATABASE your_db;
CREATE USER your_user WITH PASSWORD 'FROM_SOPS';
GRANT ALL PRIVILEGES ON DATABASE your_db TO your_user;
```

**Add password to SOPS:**
```bash
sops ansible/group_vars/production/secrets.yml
# Add: your_app_db_password: "generated_password"
```

---

## Adding Prometheus Metrics

If your application exports Prometheus metrics:

```yaml
networks:
  - monitoring_net        # Add this network

deploy:
  labels:
    # Tell Prometheus where to scrape metrics
    - "prometheus.scrape=true"
    - "prometheus.path=/metrics"
    - "prometheus.port=8080"
```

**Update Prometheus config:**
```yaml
# stacks/observability/prometheus/prometheus.yml
scrape_configs:
  - job_name: 'my-app'
    static_configs:
      - targets: ['my-app:8080']
        labels:
          app: 'my-app'
          layer: 'applications'
```

---

## Custom Protection Level

### Override Default Protection

**Public app with custom rate limit:**
```yaml
labels:
  # Don't use auto-public-protection
  # Instead, compose your own:
  - "traefik.http.routers.my-app.middlewares=waf-coraza@file,rate-limit-custom@file,crowdsec-bouncer@swarm"
```

**Define custom rate limit:**
```yaml
# stacks/security/traefik/dynamic/custom-middlewares.yml
http:
  middlewares:
    rate-limit-custom:
      rateLimit:
        average: 100     # Custom rate
        burst: 50
        period: 1m
```

### Public App WITHOUT WAF

If you have a reason to skip WAF (e.g., WebSocket-heavy app):

```yaml
labels:
  # Skip auto-public-protection, use custom chain without WAF
  - "traefik.http.routers.my-app.middlewares=rate-limit-strict@file,crowdsec-bouncer@swarm,security-headers-public@file"
```

---

## Application Health Checks

### HTTP Health Check

```yaml
healthcheck:
  test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080/health"]
  interval: 30s      # Check every 30 seconds
  timeout: 10s       # Fail if no response in 10s
  retries: 3         # Mark unhealthy after 3 failures
  start_period: 60s  # Grace period on startup
```

### TCP Health Check

```yaml
healthcheck:
  test: ["CMD-SHELL", "nc -z localhost 8080"]
  interval: 30s
```

### Custom Script

```yaml
healthcheck:
  test: ["CMD", "/app/health-check.sh"]
  interval: 30s
```

---

## Multi-Replica Applications

### Stateless Applications (Recommended)

```yaml
deploy:
  replicas: 3      # Run 3 instances

  # Load balancer distributes traffic
  labels:
    - "traefik.http.services.my-app.loadbalancer.server.port=8080"
```

### Stateful Applications

```yaml
deploy:
  replicas: 1      # Only 1 instance

  # Pin to specific node (for local storage)
  placement:
    constraints:
      - node.hostname == orangepi
```

---

## Container Hardening Checklist

For public applications, ensure your Docker image supports:

### 1. Non-root User

**Dockerfile:**
```dockerfile
# Create non-root user
RUN addgroup -g 1000 app && \
    adduser -D -u 1000 -G app app

# Switch to non-root
USER app
```

**docker-compose.yml:**
```yaml
user: "1000:1000"
```

### 2. Read-only Filesystem

**Application must:**
- Write temp files to `/tmp` only
- Not modify its own code
- Not write logs to filesystem (use stdout/stderr)

**docker-compose.yml:**
```yaml
read_only: true
tmpfs:
  - /tmp:rw,noexec,nosuid,size=128M
```

### 3. Drop Capabilities

**docker-compose.yml:**
```yaml
cap_drop:
  - ALL
```

If your app needs specific capabilities:
```yaml
cap_drop:
  - ALL
cap_add:
  - NET_BIND_SERVICE  # Only if binding to port <1024
```

---

## Troubleshooting

### Service Not Starting

```bash
# Check service logs
docker service logs my-app_my-app --tail 50

# Check service status
docker service ps my-app_my-app

# Check events
docker service ps my-app_my-app --no-trunc
```

### Application Not Accessible

```bash
# Check Traefik router
docker service logs security_traefik | grep my-app

# Test from inside Swarm
docker run --rm --network traefik_public alpine/curl curl http://my-app:8080/health

# Check firewall
sudo ufw status
```

### WAF Blocking Legitimate Traffic

```bash
# Check WAF logs
docker service logs security_traefik | grep -i "coraza\|modsec"

# Temporarily disable WAF for testing
# Remove middlewares line from docker-compose.yml
# Re-deploy
```

---

## Examples

### Node.js API (Public)

```yaml
services:
  my-node-api:
    image: my-node-api:latest
    user: "1000:1000"
    read_only: true
    cap_drop: [ALL]

    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://user:${DB_PASSWORD}@postgresql:5432/mydb

    networks:
      - traefik_public
      - postgresql_network

    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.my-node-api.rule=Host(`api.example.com`)"
        - "traefik.http.routers.my-node-api.entrypoints=websecure"
        - "traefik.http.routers.my-node-api.tls=true"
        - "traefik.http.routers.my-node-api.middlewares=auto-public-protection@file"
        - "traefik.http.services.my-node-api.loadbalancer.server.port=3000"
```

### Python Dashboard (Internal)

```yaml
services:
  my-dashboard:
    image: my-dashboard:latest

    environment:
      - FLASK_ENV=production
      - SECRET_KEY=${FLASK_SECRET}

    networks:
      - traefik_public

    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.my-dashboard.rule=Host(`dashboard.192.168.0.2.nip.io`)"
        - "traefik.http.routers.my-dashboard.entrypoints=web"
        - "traefik.http.services.my-dashboard.loadbalancer.server.port=5000"
        # NO middlewares!
```

---

## Best Practices

### DO ✅

- Use specific image tags (not `latest` in production)
- Set resource limits
- Implement health checks
- Use SOPS for secrets
- Follow container hardening for public apps
- Test protection before going live

### DON'T ❌

- Expose database ports publicly
- Hardcode secrets in docker-compose.yml
- Skip health checks
- Use root user in containers (public apps)
- Disable WAF for public apps without good reason

---

## Next Steps

- [Architecture Overview](architecture.md)
- [Security Layers](security-layers.md)
- [Network Topology](network-topology.md)

---

**Questions?** Check [Issues](https://github.com/matttoledo/orange-juice-box/issues)
