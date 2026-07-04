# 🏗️ Orange Juice Box - Architecture

## Overview

Orange Juice Box is a complete homelab infrastructure running on Orange Pi 5 Pro with Docker Swarm, organized in secure layers with modern WAF protection.

---

## System Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                          INTERNET                                     │
└─────────────────────────┬────────────────────────────────────────────┘
                          │
                 ┌────────▼────────┐
                 │  Cloudflare CDN │  ← Layer 1: DDoS + Bot Protection
                 │  + DDoS         │
                 └────────┬────────┘
                          │ HTTPS
                 ┌────────▼────────┐
                 │  Cloudflare     │  ← Layer 2: Secure Tunnel (QUIC)
                 │  Tunnel (QUIC)  │     IP Hidden, No Exposed Ports
                 └────────┬────────┘
                          │ HTTP (private network)
         ┌────────────────▼────────────────┐
         │  Gateway + WAF Layers           │
         │  ┌────────────────────────────┐ │
         │  │  ModSecurity WAF          │ │  ← Layer 3: OWASP CRS (837 rules)
         │  │  OWASP CRS v4.19.0        │ │     Paranoia Level 2
         │  └────────────┬───────────────┘ │
         │  ┌────────────▼───────────────┐ │
         │  │  Nginx Proxy Manager      │ │  ← Layer 4: Reverse Proxy + SSL
         │  │  (Custom Build)           │ │
         │  └────────────┬───────────────┘ │
         │  ┌────────────▼───────────────┐ │
         │  │  Rate Limiting            │ │  ← Layer 5: 50 req/min (burst 25)
         │  └────────────┬───────────────┘ │
         │  ┌────────────▼───────────────┐ │
         │  │  Security Headers         │ │  ← Layer 6: HSTS, CSP, X-Frame, etc
         │  └────────────┬───────────────┘ │
         └───────────────┼─────────────────┘
                         │
                ┌────────▼────────┐
                │  CrowdSec       │  ← Layer 7: IDS/IPS (58 scenarios)
                │  IDS/IPS        │     Community Threat Intelligence
                └────────┬────────┘
                         │
         ┌───────────────┼───────────────────┐
         │               │                   │
┌────────▼──────┐  ┌────▼──────────┐  ┌─────▼───────────┐
│ Applications  │  │ Observability │  │ Infrastructure  │
│ (Public)      │  │ (LAN only)    │  │ (Backend)       │
│               │  │               │  │                 │
│ ┌───────────┐ │  │ ┌──────────┐ │  │ ┌─────────────┐ │
│ │  Verly    │ │  │ │ Grafana  │ │  │ │ PostgreSQL  │ │
│ │  Service  │ │  │ │Prometheus│ │  │ │     16      │ │
│ │           │ │  │ │  Dozzle  │ │  │ │             │ │
│ │(8 Layers)│ │  │ │Portainer │ │  │ └──────▲──────┘ │
│ └─────┬─────┘ │  │ └──────────┘ │  │        │        │
│       │       │  │(NO protection│  │ ┌──────┴──────┐ │  ← Layer 8
│       │       │  │  LAN only)   │  │ │   Redis 7   │ │     Network
└───────┼───────┘  └──────────────┘  └─────────────────┘     Encryption
        │                                                      (IPSec)
        │ postgresql_network (IPSec encrypted overlay)
        └──────────────────────────────────────────────────►
```

**Security Score: 10/10** 🏆 (All 8 layers active)

---

## Layer Organization

### Gateway Layer
**Stack Name:** `gateway`

**Services:**
- **Cloudflare Tunnel** - Secure tunnel using QUIC protocol

**Networks:**
- `public_network` - Connected to all public services

**Configuration:**
- Tunnel ID: `18d4763d-f0e7-4447-9799-40bc36858295`
- Protocol: QUIC (HTTP/3 over UDP)
- Connections: 4 active (failover redundancy)
- Routing: api.verlyvidracaria.com → waf_modsecurity:8080

---

### WAF Layer
**Stack Name:** `waf`

**Services:**
- **ModSecurity** - Web Application Firewall with OWASP CRS v4.19.0

**Configuration:**
- Rules: 837 active (OWASP Core Rule Set)
- Paranoia Level: 2 (balanced security vs false positives)
- Anomaly Threshold: 5 (inbound) / 4 (outbound)
- Backend: infrastructure_npm:80

**Protection:**
- SQL Injection (942-* rules)
- XSS (941-* rules)
- RCE, LFI/RFI, Path Traversal
- Scanner Detection, Protocol Violations

---

### Security Layer
**Stack Name:** `security`

**Services:**
- **CrowdSec** - Threat detection engine (IDS/IPS)

**Networks:**
- `public_network` - Main routing network (all public services)
- `security_internal` - Security components communication

**Configuration:**
- Version: v1.7.3
- Scenarios: 58 active
- Collections: nginx, http-cve, whitelist-good-actors, linux
- LAPI: http://crowdsec:8080

**Protection Flow (Public Apps):**
```
Request → Cloudflare → Tunnel → ModSecurity WAF → NPM → Rate Limit →
Headers → CrowdSec (monitors) → App
```

---

### Infrastructure Layer
**Stack Name:** `infrastructure`

**Services:**
- **PostgreSQL 16** - Shared database server
- **Redis 7** - Caching and message broker
- **Nginx Proxy Manager** - Reverse proxy (custom build: npm-crowdsec-modsec:1.0.0)

**NPM Configuration:**
- Admin UI: http://192.168.0.2:81
- Database: PostgreSQL (npm_db)
- Integrations: CrowdSec bouncer, ModSecurity support
- SSL/TLS: Let's Encrypt certificates
- Custom configs: Rate limiting, security headers

**Networks:**
- `postgresql_network` (encrypted with IPSec)
- `redis_network` (encrypted with IPSec)
- `public_network` (main routing network)
- `security_internal` (CrowdSec communication)

**Database Clients:**
- Verly Service → PostgreSQL (verly_db)
- NPM → PostgreSQL (npm_db)
- Redash → PostgreSQL (redash metadata db + verly_db queries)
- Redash → Redis (caching)

---

### Observability Layer
**Stack Name:** `observability`

**Services:**
- **Grafana** - Monitoring dashboards
- **Prometheus** - Metrics collection and time-series database
- **Redash** - Data visualization and business intelligence
- **Redash Worker** - Background query processor
- **Dozzle** - Real-time Docker logs viewer
- **Portainer** - Docker Swarm management UI
- **cAdvisor** - Container metrics (global mode)
- **Node Exporter** - Host system metrics (global mode)

**Networks:**
- `public_network` - Web access (LAN only)
- `monitoring_net` (encrypted) - Metrics collection
- `postgresql_network` - Redash database access
- `redis_network` - Redash cache

**Protection:** None (LAN-only access, no middlewares)

---

### Applications Layer
**Stack Name:** `verly` (and others)

**Services:**
- **Verly Service** - Spring Boot REST API (Java 21)
- _(Add your applications here)_

**Networks:**
- `public_network` - Public access
- `postgresql_network` - Database access
- `monitoring_net` - Prometheus metrics

**Protection (Public Apps):** Full stack (WAF + Rate Limit + CrowdSec + Headers)

---

## Network Topology

### All Networks (Encrypted with IPSec)

```
public_network (overlay, encrypted)
├── Traefik
├── Verly Service          [PUBLIC - Full protection]
├── Grafana                [LAN - No middlewares]
├── Prometheus             [LAN - No middlewares]
├── Redash                 [LAN - No middlewares]
├── Dozzle                 [LAN - No middlewares]
├── Portainer              [LAN - No middlewares]
└── CrowdSec Dashboard     [LAN - No middlewares]

security_internal (overlay, encrypted)
├── Traefik
├── CrowdSec
└── CrowdSec Bouncer

postgresql_network (overlay, encrypted)
├── PostgreSQL
├── Verly Service
└── Redash

redis_network (overlay, encrypted)
├── Redis
└── Redash

monitoring_net (overlay, encrypted)
├── Prometheus
├── Grafana
├── Redash
├── Verly Service
├── cAdvisor (global)
└── Node Exporter (global)
```

---

## Security Layers

### Layer 1: Network Security (UFW Firewall)

```
Firewall Rules:
├── SSH (22/tcp):        LAN only (192.168.0.0/24)
├── HTTP (80/tcp):       Public (Traefik)
├── HTTPS (443/tcp):     Public (Traefik)
└── Internal ports:      BLOCKED from internet
    ├── 3000 (Grafana)
    ├── 5000 (Redash)
    ├── 8080 (ModSecurity - unused)
    ├── 9000 (Portainer)
    └── 9090 (Prometheus)
```

### Layer 2: Application Gateway (Traefik + WAF)

**For PUBLIC applications (internet-facing):**

```
Request Flow:
  Internet
    ↓
  1. Coraza WAF (WASM)         Blocks: SQLi, XSS, RCE, LFI, Path Traversal
    ↓
  2. Rate Limiting             Blocks: DDoS, abuse (50/min limit)
    ↓
  3. CrowdSec Bouncer          Blocks: Known malicious IPs (17,000+)
    ↓
  4. Security Headers          Protects: XSS, Clickjacking, MIME sniffing
    ↓
  Application (clean traffic)
```

**For INTERNAL applications (LAN-only):**

```
Request Flow:
  LAN
    ↓
  Application (direct, no middlewares)
```

Protection via:
- UFW Firewall (blocks external access)
- Traefik routing (.nip.io domains only)
- Network segmentation (Docker overlay networks)

### Layer 3: Container Security (OWASP Docker Top 10)

**Public applications have hardening:**
- ✅ Non-root user (UID 1000)
- ✅ Read-only filesystem
- ✅ No capabilities (`cap_drop: ALL`)
- ✅ No privilege escalation
- ✅ Resource limits (CPU, memory, PIDs)
- ✅ Health checks

**Internal applications:**
- Optional hardening (recommended but not required)

### Layer 4: Application Security

**Verly Service (Spring Boot):**
- JWT authentication
- Role-based access control (RBAC)
- Password hashing (BCrypt)
- CSRF protection
- Input validation

---

## Protection Comparison

| Layer | Type | WAF | Rate Limit | CrowdSec | Headers | Hardening |
|-------|------|-----|------------|----------|---------|-----------|
| **Applications (Public)** | Internet | ✅ Coraza | ✅ 50/min | ✅ 17k IPs | ✅ Strict | ✅ OWASP |
| **Observability** | LAN | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Infrastructure** | Backend | ❌ | ❌ | ❌ | ❌ | ✅ |

**Key Insight:** Security is **focused** where it matters (internet-facing apps). Internal apps are **simple** and **fast** (trusted LAN).

---

## Docker Swarm Topology

```
Orange Pi 5 Pro (Manager + Worker)
├── security_traefik (1 replica)
├── security_crowdsec (1 replica)
├── security_bouncer-traefik (1 replica)
├── security_crowdsec-dashboard (1 replica)
├── infrastructure_postgresql (1 replica)
├── infrastructure_redis (1 replica)
├── observability_grafana (1 replica)
├── observability_prometheus (1 replica)
├── observability_redash (1 replica)
├── observability_redash-worker (1 replica)
├── observability_dozzle (1 replica)
├── observability_portainer (1 replica)
├── observability_cadvisor (global)
├── observability_node-exporter (global)
└── verly_verly-service (1 replica)
```

**Placement Constraints:**
- Manager-only: Traefik, CrowdSec, PostgreSQL, Portainer
- Global: cAdvisor, Node Exporter

---

## CI/CD Pipeline

### Verly Service Example

```
GitHub Push (prod branch)
    │
    ├─ test (GitHub-hosted)          # Maven tests (~2min)
    ├─ build (GitHub-hosted)         # Maven package (~1min)
    ├─ docker (GitHub-hosted)        # Build ARM64 image (~2min)
    │                                # Push to ghcr.io
    └─ deploy (self-hosted)          # Orange Pi runner
        ├─ Pull latest image
        ├─ Update service (zero-downtime)
        ├─ Wait for healthy
        └─ Verify HTTP health
```

**Total Time:** 4-6 minutes from push to production

---

## High Availability & Resilience

### Health Checks
All services have robust health checks:
- Container-level (Docker healthcheck)
- Load balancer-level (Traefik healthcheck)
- Application-level (Spring Actuator, etc)

### Update Strategy
```yaml
update_config:
  order: start-first      # New container starts before old stops
  failure_action: rollback  # Auto-rollback on failure
  monitor: 60s            # Monitor health for 60s before considering success
```

**Result:** Zero-downtime deployments with automatic rollback!

### Resource Limits
All services have CPU/memory limits to prevent resource exhaustion:
- Limits: Maximum resources allowed
- Reservations: Guaranteed minimum resources
- PID limits: Prevents fork bombs

---

## Scalability Path

**Current:** Single-node Swarm (Orange Pi 5 Pro)

**Future:** Multi-node Swarm

```
Manager Node: Orange Pi 5 Pro
Worker Nodes: Additional Orange Pi or Raspberry Pi devices

# Add worker node
docker swarm join --token <worker-token> <manager-ip>:2377
```

Services will automatically distribute across nodes based on:
- Placement constraints
- Resource availability
- Health status

---

## Best Practices Implemented

✅ Infrastructure as Code (Git versioning)
✅ Secrets encrypted (SOPS + age)
✅ Zero-downtime deployments
✅ Automatic rollback on failure
✅ Robust health checks
✅ Complete monitoring (Prometheus + Grafana)
✅ Security hardening (UFW, SSH, fail2ban)
✅ Modern WAF (Coraza WASM, 23x faster)
✅ Defense in depth (multiple security layers)
✅ Network encryption (IPSec on all overlay networks)
✅ Container hardening (OWASP Docker Top 10)
✅ Resource limits (prevent resource exhaustion)
✅ Separation of concerns (layer-based organization)
✅ Self-hosted CI/CD (GitHub Actions runner)
✅ Beautiful UI organization (Portainer labels)

---

## Technology Stack

### Core Infrastructure
- **OS**: Ubuntu 22.04 LTS ARM64
- **Container Runtime**: Docker Engine 24.0+
- **Orchestration**: Docker Swarm
- **Networking**: Overlay networks with IPSec encryption

### Security Stack
- **Reverse Proxy**: Traefik v3.1
- **WAF**: Coraza (WASM plugin, OWASP CRS v4)
- **IDS/IPS**: CrowdSec v1.6+
- **Firewall**: UFW (Uncomplicated Firewall)

### Data Stack
- **Database**: PostgreSQL 16 (Alpine)
- **Cache**: Redis 7 (Alpine)

### Monitoring Stack
- **Metrics**: Prometheus
- **Visualization**: Grafana
- **Data Analytics**: Redash
- **Logs**: Dozzle
- **Management**: Portainer CE
- **Container Metrics**: cAdvisor
- **Host Metrics**: Node Exporter

### Application Stack
- **Framework**: Spring Boot 3.2.5
- **Language**: Java 21 (Eclipse Temurin)
- **Build Tool**: Maven
- **CI/CD**: GitHub Actions

---

## Performance Characteristics

### WAF Performance
- **Coraza WASM**: ~5ms overhead per request
- **23x faster** than standalone ModSecurity
- Native integration with Traefik (no additional container)

### Network Encryption
- **IPSec overhead**: ~5-10% throughput reduction
- **Worth it**: Zero Trust security model

### Resource Usage (Typical)
```
Service          CPU      Memory
─────────────────────────────────────
Traefik          0.1-0.3  128M
CrowdSec         0.1-0.2  256M
PostgreSQL       0.2-0.5  512M-1G
Verly Service    0.3-0.8  384M-768M
Grafana          0.1-0.3  256M-512M
Prometheus       0.3-0.6  512M-1G
Redash           0.4-0.8  512M-1G
Other services   0.1-0.2  64M-256M
─────────────────────────────────────
Total            ~2-4     ~4-7G
```

**Orange Pi 5 Pro capacity:** 8 cores, 16GB RAM - Plenty of headroom! ✅

---

## Security Model

### Public Applications (Internet-facing)
```
Threat Level: HIGH
Protection: MAXIMUM

Layers:
1. Network (UFW)
2. WAF (Coraza - OWASP CRS)
3. Rate Limiting (DDoS protection)
4. IDS/IPS (CrowdSec)
5. Security Headers (Browser protection)
6. Container Hardening (OWASP)
7. Application Security (Spring Security)
```

### Internal Applications (LAN-only)
```
Threat Level: LOW
Protection: MINIMAL

Layers:
1. Network (UFW - blocks external access)
2. Physical Security (LAN is physically controlled)
3. Network Segmentation (Docker overlay networks)
4. Access Control (Traefik routing to .nip.io only)

No middlewares = Maximum performance! ⚡
```

---

## Deployment Strategy

### Deploy Order

```bash
1. security        # Must be first (provides Traefik)
   ↓ (wait 15s)
2. infrastructure  # Must be before apps (provides database)
   ↓ (wait 10s)
3. observability   # Can be parallel with apps
   ↓ (wait 10s)
4. applications    # Last (depends on infrastructure)
```

### Update Strategy

**Rolling updates with zero downtime:**
```yaml
update_config:
  parallelism: 1         # Update one container at a time
  delay: 10s             # Wait 10s between updates
  failure_action: rollback  # Auto-rollback on failure
  monitor: 60s           # Monitor for 60s before next update
  order: start-first     # Start new before stopping old
```

**Result:** Users never see downtime during updates!

---

## Disaster Recovery

### Backup Strategy
```
Daily:   PostgreSQL (automated via cron)
Weekly:  Traefik ACME, Grafana, Portainer
Monthly: Full backup of all volumes
```

### Recovery Process
```bash
# Restore volumes
./scripts/restore-volumes.sh /path/to/backup

# Re-deploy all layers
./scripts/deploy-all.sh

# Verify health
docker service ls
```

**RTO (Recovery Time Objective):** < 15 minutes
**RPO (Recovery Point Objective):** < 24 hours

---

## Monitoring & Observability

### Metrics Collection

```
Applications → Prometheus ← cAdvisor (container metrics)
                          ← Node Exporter (host metrics)
                          ← Spring Actuator (app metrics)
                          ← Traefik (proxy metrics)
```

### Visualization

```
Prometheus → Grafana Dashboards
          → Alertmanager → Notifications (future)
```

### Data Analytics

```
PostgreSQL (verly_db) → Redash → Business Dashboards
                               → SQL Queries
                               → Reports
```

### Logs

```
Containers → Docker logs → Dozzle (real-time viewer)
          → CrowdSec (security analysis - public apps only)
```

---

## Next Steps

See documentation for:
- [Security Layers](security-layers.md) - Detailed security documentation
- [Adding Applications](adding-applications.md) - How to deploy new apps
- [Network Topology](network-topology.md) - Detailed network diagrams

---

**Last Updated:** 2025-10-21
**Version:** 2.0.0 (Layered Architecture)
