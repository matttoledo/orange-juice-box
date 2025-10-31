# Nginx Proxy Manager - Complete Guide

**Version:** 1.0.0 (Custom Build)
**Image:** npm-crowdsec-modsec:1.0.0
**Admin UI:** http://192.168.0.2:81

---

## Table of Contents

1. [Overview](#overview)
2. [Accessing the UI](#accessing-the-ui)
3. [Creating Proxy Hosts](#creating-proxy-hosts)
4. [SSL/TLS Certificates](#ssltls-certificates)
5. [Custom Nginx Configurations](#custom-nginx-configurations)
6. [Rate Limiting](#rate-limiting)
7. [Security Headers](#security-headers)
8. [Integration with CrowdSec](#integration-with-crowdsec)
9. [Monitoring & Logs](#monitoring--logs)
10. [Troubleshooting](#troubleshooting)

---

## Overview

Nginx Proxy Manager (NPM) is the central reverse proxy for Orange Juice Box v3.0, replacing Traefik with a more user-friendly web interface and integrated security features.

### Custom Build Features
- **CrowdSec Integration**: Lua bouncer for IP blocking
- **ModSecurity Support**: Ready for WAF integration
- **PostgreSQL Backend**: More robust than SQLite
- **Custom Nginx Configs**: Advanced routing capabilities

### Architecture Position
```
Cloudflare Tunnel → ModSecurity WAF → NPM → Your App
                                       ↑
                            (You configure this)
```

---

## Accessing the UI

### URL
```
http://192.168.0.2:81
```

**Note:** Admin UI is only accessible from LAN (not exposed publicly)

### Default Credentials
```
Email: admin@example.com
Password: changeme
```

**⚠️ IMPORTANT:** Change the default password on first login!

### First Login Steps
1. Open http://192.168.0.2:81
2. Login with default credentials
3. Follow the setup wizard
4. **Change email and password**
5. Configure your first proxy host

---

## Creating Proxy Hosts

### For Public Apps (via Cloudflare Tunnel)

When using Cloudflare Tunnel, you'll create proxy hosts that receive traffic from the tunnel.

**Example: api.verlyvidracaria.com**

1. **Navigate to:** Proxy Hosts → Add Proxy Host

2. **Details Tab:**
   ```
   Domain Names: api.verlyvidracaria.com
   Scheme: http
   Forward Hostname/IP: applications_verly-service
   Forward Port: 8080
   Cache Assets: ✅ (optional)
   Block Common Exploits: ✅
   Websockets Support: ❌ (for REST APIs)
   Access List: None (Cloudflare handles auth)
   ```

3. **SSL Tab:**
   ```
   SSL Certificate: None
   Force SSL: ❌
   HTTP/2 Support: ✅
   HSTS Enabled: ❌ (handled by custom config)
   ```

   **Why no SSL?** Cloudflare Tunnel terminates TLS and sends HTTP to NPM.

4. **Advanced Tab:**
   ```nginx
   # Rate limiting (50 req/min)
   limit_req_zone $binary_remote_addr zone=verly_api:10m rate=50r/m;
   limit_req zone=verly_api burst=25 nodelay;
   limit_req_status 429;

   # Security headers
   add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
   add_header X-Frame-Options "DENY" always;
   add_header X-Content-Type-Options "nosniff" always;
   add_header X-XSS-Protection "1; mode=block" always;
   add_header Referrer-Policy "strict-origin-when-cross-origin" always;
   add_header Permissions-Policy "camera=(), microphone=(), geolocation=(), payment=(), usb=()" always;
   add_header Content-Security-Policy "default-src 'self'; frame-ancestors 'none';" always;

   # Health check endpoint (no logging)
   location /verly-service/actuator/health {
       proxy_pass http://applications_verly-service:8080;
       access_log off;
   }
   ```

5. **Click Save**

### For Internal Apps (LAN Only)

**Example: Grafana on .nip.io domain**

1. **Details Tab:**
   ```
   Domain Names: grafana.192.168.0.2.nip.io
   Scheme: http
   Forward Hostname/IP: observability_grafana
   Forward Port: 3000
   Block Common Exploits: ❌ (LAN is trusted)
   ```

2. **SSL Tab:**
   ```
   SSL Certificate: None (LAN doesn't need HTTPS)
   ```

3. **Advanced Tab:** (leave empty for simple proxy)

---

## SSL/TLS Certificates

### For Public Domains (Let's Encrypt)

If you're NOT using Cloudflare Tunnel and want NPM to handle SSL:

1. **Navigate to:** SSL Certificates → Add SSL Certificate

2. **Let's Encrypt:**
   ```
   Domain Names: yourdomain.com
   Email: your-email@example.com
   Use a DNS Challenge: ❌ (use HTTP challenge)
   Agree to Let's Encrypt ToS: ✅
   ```

3. **Click Save**

4. **Apply to Proxy Host:**
   - Edit proxy host → SSL Tab
   - SSL Certificate: Select your certificate
   - Force SSL: ✅
   - HTTP/2: ✅

### Auto-Renewal
NPM automatically renews Let's Encrypt certificates 30 days before expiration.

### Viewing Certificates
```bash
# Inside NPM container
docker exec $(docker ps -qf name=infrastructure_npm) \
  ls -la /etc/letsencrypt/live/
```

---

## Custom Nginx Configurations

### Location: Advanced Tab in Proxy Host

NPM allows custom Nginx directives in the "Advanced" tab of each proxy host.

### Common Patterns

#### 1. Custom Headers
```nginx
add_header X-Custom-Header "value" always;
```

#### 2. IP Whitelisting
```nginx
allow 192.168.0.0/24;
allow 10.0.0.0/8;
deny all;
```

#### 3. Basic Auth
```nginx
auth_basic "Restricted Area";
auth_basic_user_file /data/nginx/htpasswd;
```

#### 4. Custom Locations
```nginx
location /api/ {
    proxy_pass http://backend-api:8080/;
}

location /static/ {
    alias /var/www/static/;
}
```

#### 5. Websockets
```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

---

## Rate Limiting

### Configuration

Rate limiting is implemented via custom Nginx config in the Advanced tab.

### Basic Rate Limiting
```nginx
# Define zone (put at http level or in custom config file)
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=50r/m;

# Apply to location (put in Advanced tab)
limit_req zone=api_limit burst=25 nodelay;
limit_req_status 429;
```

### Explanation
- **Zone**: `api_limit` (10MB memory)
- **Rate**: 50 requests per minute
- **Burst**: 25 additional requests allowed
- **Mode**: `nodelay` (immediate 429 response)

### Per-Endpoint Rate Limiting
```nginx
# Different limits for different endpoints
location /api/login {
    limit_req_zone $binary_remote_addr zone=login_limit:5m rate=5r/m;
    limit_req zone=login_limit burst=2 nodelay;
    proxy_pass http://backend:8080;
}

location /api/data {
    limit_req_zone $binary_remote_addr zone=data_limit:10m rate=100r/m;
    limit_req zone=data_limit burst=50 nodelay;
    proxy_pass http://backend:8080;
}
```

### Testing Rate Limiting
```bash
# Send 30 rapid requests
for i in {1..30}; do
  curl -s -o /dev/null -w "%{http_code} " http://your-domain.com/
done
echo ""

# Expected: 200 200 ... 429 429 429
```

---

## Security Headers

### OWASP Recommended Headers

All public apps should include these headers in the Advanced tab:

```nginx
# HSTS - Force HTTPS
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

# Clickjacking Protection
add_header X-Frame-Options "DENY" always;

# MIME Sniffing Protection
add_header X-Content-Type-Options "nosniff" always;

# XSS Protection
add_header X-XSS-Protection "1; mode=block" always;

# Referrer Policy
add_header Referrer-Policy "strict-origin-when-cross-origin" always;

# Feature Policy
add_header Permissions-Policy "camera=(), microphone=(), geolocation=(), payment=(), usb=()" always;

# Content Security Policy
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self'; frame-ancestors 'none';" always;
```

### Verifying Headers
```bash
curl -I https://your-domain.com | grep -E "(strict-transport|x-frame|content-security)"
```

---

## Integration with CrowdSec

### Current Setup

NPM custom build includes CrowdSec Lua bouncer at `/etc/nginx/lua/crowdsec.lua`.

### How It Works
1. CrowdSec monitors logs and detects threats
2. Malicious IPs are added to ban list
3. NPM Lua bouncer queries CrowdSec LAPI
4. Banned IPs receive HTTP 403

### Configuration
```yaml
# In infrastructure/docker-compose.yml
environment:
  - CROWDSEC_LAPI_URL=http://crowdsec:8080
  - CROWDSEC_LAPI_KEY=${CROWDSEC_BOUNCER_KEY}
```

### Verifying Connection
```bash
# From NPM container
docker exec $(docker ps -qf name=infrastructure_npm) \
  curl -s -o /dev/null -w "%{http_code}" http://crowdsec:8080/v1/heartbeat

# Expected: 401 (unauthorized, but reachable)
```

### Checking Banned IPs
```bash
# From CrowdSec container
docker exec $(docker ps -qf name=security_crowdsec) cscli decisions list
```

---

## Monitoring & Logs

### Access Logs

```bash
# View access logs for specific proxy host
docker exec $(docker ps -qf name=infrastructure_npm) \
  tail -f /var/log/nginx/verly-api-access.log
```

### Error Logs

```bash
# View error logs
docker exec $(docker ps -qf name=infrastructure_npm) \
  tail -f /var/log/nginx/verly-api-error.log
```

### Rate Limiting Logs

```bash
# See rate limit blocks
docker exec $(docker ps -qf name=infrastructure_npm) \
  grep "limiting requests" /var/log/nginx/verly-api-error.log
```

### Service Status

```bash
# Check NPM service
docker service ps infrastructure_npm

# Check logs
docker service logs infrastructure_npm --tail 50
```

---

## Troubleshooting

### Issue: Cannot Access Admin UI

**Symptom:** http://192.168.0.2:81 not loading

**Solutions:**
```bash
# 1. Check if service is running
docker service ps infrastructure_npm

# 2. Check if port is exposed
docker service inspect infrastructure_npm | grep -A5 PublishedPort

# 3. Check container logs
docker service logs infrastructure_npm --tail 50

# 4. Restart service
docker service update infrastructure_npm --force
```

### Issue: Proxy Host Returns 502 Bad Gateway

**Symptom:** Proxy host configured but returns 502

**Solutions:**
```bash
# 1. Check if backend service is running
docker service ps applications_verly-service

# 2. Test backend directly from NPM container
docker exec $(docker ps -qf name=infrastructure_npm) \
  curl -I http://applications_verly-service:8080

# 3. Check networks
docker service inspect infrastructure_npm | grep Networks
docker service inspect applications_verly-service | grep Networks

# 4. Check nginx error logs
docker exec $(docker ps -qf name=infrastructure_npm) \
  tail -20 /var/log/nginx/error.log
```

### Issue: SSL Certificate Not Renewing

**Symptom:** Certificate expired or renewal failing

**Solutions:**
```bash
# 1. Check certificate status
docker exec $(docker ps -qf name=infrastructure_npm) \
  ls -la /etc/letsencrypt/live/

# 2. Manual renewal
# Via NPM UI: SSL Certificates → Click certificate → Renew

# 3. Check renewal logs
docker service logs infrastructure_npm | grep -i "renew"
```

### Issue: Rate Limiting Not Working

**Symptom:** No HTTP 429 responses

**Solutions:**
```bash
# 1. Check if limit_req_zone is defined
docker exec $(docker ps -qf name=infrastructure_npm) \
  grep -r "limit_req_zone" /etc/nginx/conf.d/

# 2. Verify nginx syntax
docker exec $(docker ps -qf name=infrastructure_npm) nginx -t

# 3. Reload nginx
docker exec $(docker ps -qf name=infrastructure_npm) nginx -s reload

# 4. Test with rapid requests
for i in {1..30}; do curl -s -o /dev/null -w "%{http_code} " http://your-domain.com/; done
```

### Issue: Custom Config Not Applied

**Symptom:** Advanced tab config not working

**Solutions:**
```bash
# 1. Check nginx syntax
docker exec $(docker ps -qf name=infrastructure_npm) nginx -t

# 2. View generated config
docker exec $(docker ps -qf name=infrastructure_npm) \
  cat /etc/nginx/conf.d/your-proxy.conf

# 3. Reload nginx
docker exec $(docker ps -qf name=infrastructure_npm) nginx -s reload
```

---

## Advanced Configurations

### Persistent Custom Configs

To persist custom Nginx configs across container restarts:

1. **Create config directory:**
   ```bash
   mkdir -p /home/matt/orange-juice-box/stacks/infrastructure/npm/conf.d
   ```

2. **Create custom config file:**
   ```bash
   cat > /home/matt/orange-juice-box/stacks/infrastructure/npm/conf.d/verly-api.conf << 'EOF'
   # Your custom Nginx config
   limit_req_zone $binary_remote_addr zone=verly_api:10m rate=50r/m;

   server {
       listen 80;
       server_name api.verlyvidracaria.com;

       # Your config here...
   }
   EOF
   ```

3. **Add volume to docker-compose.yml:**
   ```yaml
   volumes:
     - ./npm/conf.d:/etc/nginx/conf.d/custom:ro
   ```

4. **Redeploy:**
   ```bash
   docker stack deploy -c infrastructure/docker-compose.yml infrastructure
   ```

### Global Rate Limiting

To apply rate limiting globally (all proxy hosts):

1. **Create:** `/etc/nginx/conf.d/global-rate-limit.conf`
   ```nginx
   limit_req_zone $binary_remote_addr zone=global:10m rate=100r/m;
   ```

2. **Apply in each proxy host Advanced tab:**
   ```nginx
   limit_req zone=global burst=50 nodelay;
   ```

### IP Whitelisting for Admin UI

**Goal:** Only allow specific IPs to access NPM admin UI

**Solution:** Add to NPM config or use firewall rules.

---

## Database Management

### NPM PostgreSQL Database

```
Database: npm_db
User: npm_user
Password: gdc4QwsPiIJHienvZRZMOR7MJpzdNbi1
Host: postgresql (Docker service name)
Port: 5432
```

### Accessing Database
```bash
# Connect to PostgreSQL
docker exec -it $(docker ps -qf name=infrastructure_postgresql) \
  psql -U npm_user -d npm_db

# List tables
\dt

# View proxy hosts
SELECT * FROM proxy_host;
```

### Backup NPM Configuration
```bash
# Backup database
docker exec $(docker ps -qf name=infrastructure_postgresql) \
  pg_dump -U npm_user npm_db > npm_backup_$(date +%Y%m%d).sql

# Restore
docker exec -i $(docker ps -qf name=infrastructure_postgresql) \
  psql -U npm_user npm_db < npm_backup_20251031.sql
```

---

## Best Practices

### 1. Security Headers on All Public Apps
Always include the full set of security headers in Advanced tab.

### 2. Rate Limiting Based on Use Case
- **APIs:** 50-100 req/min
- **Login endpoints:** 5-10 req/min
- **Static content:** 200-500 req/min

### 3. Separate Configs for Different Apps
Don't put all proxy hosts in one config file. Use NPM UI to create separate proxy hosts.

### 4. Monitor Logs Regularly
```bash
# Check for errors weekly
docker exec $(docker ps -qf name=infrastructure_npm) \
  tail -100 /var/log/nginx/error.log
```

### 5. Test Changes Before Production
Always test custom Nginx configs:
```bash
docker exec $(docker ps -qf name=infrastructure_npm) nginx -t
```

---

## Migration from Traefik

### Key Differences

| Feature | Traefik | NPM |
|---------|---------|-----|
| **Configuration** | Docker labels | Web UI + files |
| **SSL** | Let's Encrypt auto | Manual via UI |
| **Middleware** | Labels | Advanced tab |
| **Discovery** | Automatic | Manual creation |
| **UI** | Basic dashboard | Full admin UI |

### Migration Steps

1. **Identify Traefik services:**
   ```bash
   grep -r "traefik.enable=true" stacks/
   ```

2. **For each service:**
   - Note domain, port, middlewares
   - Create equivalent proxy host in NPM
   - Convert middlewares to Nginx config

3. **Example:** Traefik labels → NPM config

   **Traefik:**
   ```yaml
   labels:
     - "traefik.http.routers.app.rule=Host(`app.example.com`)"
     - "traefik.http.routers.app.middlewares=rate-limit,security-headers"
     - "traefik.http.services.app.loadbalancer.server.port=8080"
   ```

   **NPM Equivalent:**
   - Domain: `app.example.com`
   - Forward: `service_name:8080`
   - Advanced: Rate limit + headers config

4. **Test before switching:**
   - Deploy NPM proxy host
   - Test with different domain (test.example.com)
   - Once working, update DNS/Cloudflare to point to new config

---

## Common Use Cases

### 1. Static Website
```
Domain: site.example.com
Forward: nginx_static:80
SSL: Let's Encrypt
Advanced: Cache headers
```

### 2. API with Rate Limiting
```
Domain: api.example.com
Forward: api_service:8080
SSL: None (Cloudflare Tunnel)
Advanced: Rate limit 50/min + security headers
```

### 3. WebSocket Application
```
Domain: ws.example.com
Forward: websocket_service:3000
Websockets: ✅ Enabled
SSL: Let's Encrypt
```

### 4. Multiple Backends (Load Balancing)
```nginx
# In Advanced tab
upstream backend {
    server app1:8080;
    server app2:8080;
    server app3:8080;
}

location / {
    proxy_pass http://backend;
}
```

---

## Security Checklist

When creating a new public proxy host:

- [ ] Enable "Block Common Exploits"
- [ ] Add rate limiting (appropriate for use case)
- [ ] Add all security headers
- [ ] Test with security scanner (OWASP ZAP)
- [ ] Enable access logging
- [ ] Configure health check endpoint (if applicable)
- [ ] Test SSL certificate (if using Let's Encrypt)
- [ ] Verify backend service is running
- [ ] Test failover (if load balanced)

---

## References

- **NPM Official Docs:** https://nginxproxymanager.com/guide/
- **Nginx Docs:** https://nginx.org/en/docs/
- **Rate Limiting:** https://nginx.org/en/docs/http/ngx_http_limit_req_module.html
- **Security Headers:** https://owasp.org/www-project-secure-headers/

---

**Last Updated:** 2025-10-31
**Version:** 1.0.0
**Status:** Production-ready ✅
