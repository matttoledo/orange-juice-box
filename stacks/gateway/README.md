# Gateway Stack - Cloudflare Tunnel

**Layer:** 1 (Gateway)
**Protocol:** QUIC (HTTP/3)
**Services:** 1 (cloudflare-tunnel)

---

## Overview

The Gateway stack provides secure internet connectivity via **Cloudflare Tunnel** using the QUIC protocol (HTTP/3), eliminating the need to expose public ports (80/443) and hiding the origin server IP.

### Architecture Position
```
Internet → Cloudflare CDN → Cloudflare Tunnel → ModSecurity WAF → ...
                            ↑
                   (This stack)
```

---

## Services

### cloudflare-tunnel

**Image:** `cloudflare/cloudflared:latest`
**Protocol:** QUIC (HTTP/3 over UDP)
**Connections:** 4 active (automatic failover)

#### Configuration
```yaml
Tunnel ID: 18d4763d-f0e7-4447-9799-40bc36858295
Command: tunnel run --token ${TUNNEL_TOKEN}
Network: public_network
Replicas: 1
```

#### Routing
```yaml
Ingress Rules (managed in Cloudflare Dashboard):
  - hostname: api.verlyvidracaria.com
    service: http://waf_modsecurity:8080
  - service: http_status:404
```

#### Resources
```
CPU Limit: 0.25 cores
Memory Limit: 128MB
CPU Reservation: 0.1 cores
Memory Reservation: 64MB
```

---

## Benefits

### 1. IP Address Hidden
Your origin server IP is never exposed publicly, protecting against:
- Direct attacks on IP
- Port scanning
- Reconnaissance

### 2. Zero Exposed Ports
Ports 80 and 443 are NOT published publicly:
- No firewall rules needed for public traffic
- Reduced attack surface
- Easier security management

### 3. QUIC Protocol (HTTP/3)
- **Faster**: UDP-based, no head-of-line blocking
- **More Reliable**: Better performance on lossy networks
- **Modern**: Latest HTTP protocol

### 4. Automatic Failover
- **4 Connections**: Redundant connections to different Cloudflare data centers
- **Locations**: gig02, gig09, gig10 (automatically selected)
- **Health Checks**: Automatic reconnection on failure

### 5. DDoS Protection
All traffic passes through Cloudflare's global network first:
- Automatic DDoS mitigation
- Bot management
- Rate limiting at edge

---

## Deployment

### Prerequisites
1. Cloudflare account with domain
2. Tunnel created in Cloudflare Zero Trust dashboard
3. Tunnel token (TUNNEL_TOKEN environment variable)

### Deploy Stack
```bash
cd /home/matt/orange-juice-box/stacks/gateway

# Set tunnel token (or use .env file)
export TUNNEL_TOKEN="<your-tunnel-token>"

# Deploy
docker stack deploy -c docker-compose.yml gateway
```

### Verify Deployment
```bash
# Check service status
docker service ps gateway_cloudflare-tunnel

# Check logs (should see "Registered tunnel connection" 4 times)
docker service logs gateway_cloudflare-tunnel | grep "Registered tunnel"

# Expected output:
# Registered tunnel connection connIndex=0 connection=xxx...
# Registered tunnel connection connIndex=1 connection=xxx...
# Registered tunnel connection connIndex=2 connection=xxx...
# Registered tunnel connection connIndex=3 connection=xxx...
```

---

## Configuration

### Environment Variables

**Required:**
- `TUNNEL_TOKEN` - Cloudflare tunnel token (from dashboard)

### Cloudflare Dashboard Configuration

**Location:** https://dash.cloudflare.com/ → Zero Trust → Networks → Tunnels

1. **Select tunnel:** verly-tunnel (18d4763d-f0e7-4447-9799-40bc36858295)

2. **Public Hostnames tab:**
   - Click "Add a public hostname"
   - Hostname: `api.verlyvidracaria.com`
   - Service: `http://waf_modsecurity:8080`
   - Path: (leave empty or `*`)
   - Save

3. **Tunnel updates automatically** (no restart needed)

### Adding New Domains

To route a new domain through the tunnel:

1. **In Cloudflare Dashboard:**
   - Navigate to tunnel → Public Hostnames
   - Click "Add a public hostname"
   - Hostname: `new-domain.example.com`
   - Service: `http://service-name:port`
   - Save

2. **Tunnel picks up changes automatically** (30-60 seconds)

3. **Verify:**
   ```bash
   docker service logs gateway_cloudflare-tunnel | grep "Updated to new configuration"
   # Should show version increment
   ```

---

## Monitoring

### Health Checks

```bash
# 1. Service status
docker service ps gateway_cloudflare-tunnel

# Expected: Running

# 2. Connection status
docker service logs gateway_cloudflare-tunnel --tail 50 | \
  grep -E "(Registered|connection)"

# Expected: 4 "Registered tunnel connection" messages

# 3. Recent errors
docker service logs gateway_cloudflare-tunnel --tail 100 | \
  grep -i error

# Should be empty (or only warning about cert path)
```

### Connection Monitoring

```bash
# Monitor live connections
docker service logs gateway_cloudflare-tunnel --follow
```

**Healthy Output:**
```
INF Registered tunnel connection connIndex=0 location=gig09
INF Registered tunnel connection connIndex=1 location=gig10
INF Registered tunnel connection connIndex=2 location=gig02
INF Registered tunnel connection connIndex=3 location=gig10
```

### Performance Metrics

```bash
# Check tunnel metrics (exposed on port 20241)
curl -s http://localhost:20241/metrics
```

---

## Troubleshooting

### Issue: Error 1033 (Tunnel Not Found)

**Symptom:** Website shows "Cloudflare Tunnel error 1033"

**Cause:** Tunnel is down or cannot connect to Cloudflare

**Solutions:**
```bash
# 1. Check if service is running
docker service ps gateway_cloudflare-tunnel

# 2. Check logs for errors
docker service logs gateway_cloudflare-tunnel --tail 50

# 3. Restart tunnel
docker service update gateway_cloudflare-tunnel --force

# 4. Verify tunnel is active in Cloudflare Dashboard
# Zero Trust → Networks → Tunnels → verly-tunnel → Status should be "Healthy"
```

### Issue: "Unauthorized: Failed to get tunnel"

**Symptom:** Logs show "Unauthorized: Failed to get tunnel"

**Cause:** Tunnel token is invalid or tunnel was deleted

**Solutions:**
1. **Regenerate tunnel token:**
   - Cloudflare Dashboard → Zero Trust → Networks → Tunnels
   - Click on tunnel → Configure
   - Install connector → Copy new token

2. **Update TUNNEL_TOKEN:**
   ```bash
   # Update in docker-compose.yml or .env file
   export TUNNEL_TOKEN="<new-token>"
   docker stack deploy -c docker-compose.yml gateway
   ```

### Issue: "dial tcp: lookup <service> on 127.0.0.11:53: no such host"

**Symptom:** Tunnel cannot find backend service

**Cause:** Service name incorrect or service not running

**Solutions:**
```bash
# 1. Verify backend service is running
docker service ps waf_modsecurity

# 2. Check service name in Cloudflare Dashboard
# Must match: http://waf_modsecurity:8080 (Docker service name)

# 3. Verify both are on same network
docker service inspect gateway_cloudflare-tunnel | grep Networks
docker service inspect waf_modsecurity | grep Networks

# Should both show: public_network
```

### Issue: Slow Response Times

**Symptom:** Website is slow despite tunnel being healthy

**Possible Causes:**
1. **Backend service slow** - Check app logs
2. **WAF processing overhead** - Tune ModSecurity rules
3. **Network congestion** - Check bandwidth

**Diagnostics:**
```bash
# Test each layer separately
curl -w "@curl-format.txt" https://api.verlyvidracaria.com/...

# curl-format.txt:
time_namelookup: %{time_namelookup}\n
time_connect: %{time_connect}\n
time_starttransfer: %{time_starttransfer}\n
time_total: %{time_total}\n
```

---

## Configuration Files

### docker-compose.yml
```yaml
version: '3.8'

networks:
  public_network:
    external: true

services:
  cloudflare-tunnel:
    image: cloudflare/cloudflared:latest
    command: tunnel run --token ${TUNNEL_TOKEN}
    networks:
      - public_network
    deploy:
      replicas: 1
      resources:
        limits:
          cpus: '0.25'
          memory: 128M
```

### Environment Variables (.env)
```bash
TUNNEL_TOKEN=<get-from-cloudflare-dashboard>
```

---

## Security Considerations

### 1. Tunnel Token is Sensitive
- Store in environment variable or encrypted secrets
- Never commit to Git
- Rotate periodically

### 2. Tunnel Runs as Root
- Container needs elevated permissions
- Keep image updated for security patches

### 3. Monitor Connection Health
- Set up alerts for connection failures
- Monitor logs daily

---

## Advanced Topics

### Multiple Domains

Route multiple domains through single tunnel:

**Cloudflare Dashboard Configuration:**
```
Public Hostnames:
  - api.example.com → http://waf_modsecurity:8080
  - app.example.com → http://app_service:3000
  - admin.example.com → http://admin_service:8000
```

All domains automatically routed without restarting tunnel.

### Private Network (WARP)

Cloudflare Tunnel can also route private network traffic (not just HTTP):

```yaml
# Enable in Cloudflare Dashboard:
Settings → Private Network → Enable
```

Use cases:
- SSH access without exposing port 22
- RDP connections
- Database access

### IPv6 Support

Cloudflare Tunnel supports IPv6:
- Automatically enabled
- No configuration needed
- Dual stack (IPv4 + IPv6)

---

## Backup & Disaster Recovery

### Backup Configuration
```bash
# Tunnel configuration
cp /home/matt/.cloudflared/config.yml \
   /home/matt/backups/cloudflared-config-$(date +%Y%m%d).yml

# Tunnel credentials
cp /home/matt/.cloudflared/verly-tunnel.json \
   /home/matt/backups/tunnel-credentials-$(date +%Y%m%d).json
```

### Restore
```bash
# Restore configuration
cp /home/matt/backups/cloudflared-config-20251031.yml \
   /home/matt/.cloudflared/config.yml

# Redeploy
docker stack deploy -c docker-compose.yml gateway
```

### Disaster Recovery

If tunnel is completely lost:
1. Create new tunnel in Cloudflare Dashboard
2. Copy new tunnel token
3. Update TUNNEL_TOKEN in docker-compose.yml
4. Redeploy stack
5. Update DNS (if needed)

---

**Stack:** gateway
**Status:** Active ✅
**Connections:** 4/4 healthy ✅
**Last Updated:** 2025-10-31
