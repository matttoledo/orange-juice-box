# 🍊 Orange Juice Box

> Infrastructure as Code for Orange Pi Docker Swarm (ARM64)

**Orange Juice Box** is a complete homelab infrastructure for Orange Pi 5 Pro, organized in secure layers with modern WAF protection and zero-config deployment for new applications.

```
🍊 Orange     - Orange Pi hardware (ARM64)
🧃 Juice      - The infrastructure "juice" (Docker, Traefik, apps)
📦 Box        - Container that organizes everything
```

---

## 🏗️ Architecture

- **Hardware**: Orange Pi 5 Pro (RK3588, 8-core ARM64)
- **OS**: Ubuntu 22.04 LTS ARM64
- **Orchestrator**: Docker Swarm (single-node)
- **Gateway**: Cloudflare Tunnel (QUIC protocol)
- **Reverse Proxy**: Nginx Proxy Manager (custom build with CrowdSec + ModSecurity)
- **WAF**: ModSecurity with OWASP CRS v4.19.0 (837 rules active)
- **IDS/IPS**: CrowdSec v1.7.3 (58 threat scenarios)
- **Rate Limiting**: 50 requests/min (burst 25)
- **Security Headers**: HSTS, CSP, X-Frame-Options, etc
- **Monitoring**: Prometheus + Grafana
- **Data Visualization**: Redash
- **Database**: PostgreSQL 16
- **Secrets**: SOPS + age encryption
- **CI/CD**: GitHub Actions (self-hosted runner)

---

## 📦 Layer Organization

Infrastructure is organized in **5 clean layers** by responsibility:

```
stacks/
├── gateway/            Gateway Layer - Cloudflare Tunnel
├── security/           Security Layer - ModSecurity WAF + CrowdSec IDS/IPS
├── infrastructure/     Infrastructure Layer - PostgreSQL, Redis, NPM
├── observability/      Observability Layer - Grafana, Prometheus, Dozzle, Portainer
└── applications/       Applications Layer - Verly Service + your apps
```

### Layer 1: Gateway
**Services:** Cloudflare Tunnel

**Responsibility:** Secure internet gateway via QUIC protocol, no exposed ports, IP hidden

### Layer 2: Security
**Services:** ModSecurity WAF (837 rules OWASP CRS v4.19.0), CrowdSec IDS/IPS

**Responsibility:** WAF protection (SQLi, XSS, RCE), threat detection, IP blocking

### Layer 3: Infrastructure
**Services:** PostgreSQL 16, Redis 7, Nginx Proxy Manager

**Responsibility:** Reverse proxy, SSL/TLS termination, shared data services

### Layer 4: Observability
**Services:** Grafana, Prometheus, Dozzle, Portainer, cAdvisor, Node Exporter

**Responsibility:** Monitoring, metrics, logs, dashboards, container management

### Layer 5: Applications
**Services:** Verly Service (+ your applications)

**Responsibility:** Business logic, APIs, microservices

---

## 🛡️ Automatic Protection - 8 Layers of Defense in Depth

### Public Applications (Internet-facing)

All public apps get **8 layers of automatic protection** with enterprise-grade security:

```
Internet → Cloudflare CDN → Cloudflare Tunnel → ModSecurity WAF →
NPM → Rate Limit → Security Headers → CrowdSec → Your App
```

**8-Layer Protection Stack:**
1. ✅ **Cloudflare CDN + DDoS** - Global edge network, automatic DDoS mitigation
2. ✅ **Cloudflare Tunnel (QUIC)** - Encrypted tunnel, no exposed ports, IP hidden
3. ✅ **ModSecurity WAF** - OWASP CRS v4.19.0 with 837 active rules (SQLi, XSS, RCE, LFI)
4. ✅ **Nginx Proxy Manager** - Reverse proxy, SSL/TLS termination, load balancing
5. ✅ **Rate Limiting** - 50 requests/min (burst 25) to prevent abuse and DDoS
6. ✅ **Security Headers** - HSTS, CSP, X-Frame-Options, X-XSS-Protection, etc
7. ✅ **CrowdSec IDS/IPS** - 58 threat scenarios, community intelligence
8. ✅ **Network Encryption** - IPSec on all overlay networks (Zero Trust)

**Security Score: 10/10** 🏆

**Current Protection Status:**
- ✅ **Verly Service** (api.verlyvidracaria.com) - 8 layers active
- ✅ ModSecurity blocking: XSS, SQLi, RCE attempts
- ✅ Rate limiting: Tested and blocking at 50/min
- ✅ CrowdSec: Monitoring 4 log sources

### Internal Applications (LAN-only)

Internal apps on `.nip.io` domains have **lighter protection** for maximum performance:

```
LAN → Nginx Proxy Manager → Your App
```

**Protection:**
- ✅ **UFW Firewall** - Blocks external access to internal ports
- ✅ **NPM Routing** - Only responds to `.nip.io` domains from LAN
- ✅ **Network Segmentation** - Isolated Docker networks
- ❌ NO WAF, NO Rate Limiting (trusted LAN environment)

---

## 🚀 Quick Start

### Deploy All Infrastructure

```bash
# Clone repository
git clone https://github.com/matttoledo/orange-juice-box.git
cd orange-juice-box

# Deploy all layers
./scripts/deploy-all.sh
```

### Create New Public App (with automatic protection)

```bash
# Create from template
./scripts/new-public-app.sh my-api my-api.verlyvidracaria.com 8080

# Edit configuration
cd stacks/applications/my-api
vim docker-compose.yml  # Update image, env vars

# Deploy
docker stack deploy -c docker-compose.yml my-api

# ✅ Your app is now protected by WAF + Rate Limit + CrowdSec!
```

### Create New Internal App (LAN-only, no middlewares)

```bash
# Create from template
./scripts/new-internal-app.sh my-dashboard 3000

# Edit and deploy
cd stacks/applications/my-dashboard
vim docker-compose.yml
docker stack deploy -c docker-compose.yml my-dashboard

# ✅ Fast and simple internal tool!
```

---

## 🎯 Commands

```bash
./scripts/deploy-all.sh                    # Deploy all layers in order
./scripts/deploy-layer.sh security         # Deploy specific layer
./scripts/deploy-layer.sh applications     # Deploy all applications

./scripts/new-public-app.sh NAME DOMAIN PORT    # Create public app
./scripts/new-internal-app.sh NAME PORT         # Create internal app

make help                                  # Show all make targets
```

---

## 📊 Deployed Services

| Service | Type | URL | Protection |
|---------|------|-----|------------|
| **Verly Service** | Public API | https://api.verlyvidracaria.com | 8 Layers (Cloudflare → WAF → NPM → CrowdSec) |
| **NPM Dashboard** | Admin UI | http://192.168.0.2:81 | LAN only |
| **Grafana** | Dashboard | http://grafana.192.168.0.2.nip.io | LAN only |
| **Prometheus** | Metrics | http://prometheus.192.168.0.2.nip.io | LAN only |
| **Dozzle** | Logs | http://dozzle.192.168.0.2.nip.io | LAN only |
| **Portainer** | Docker UI | http://portainer.192.168.0.2.nip.io | LAN only |

**Active Stacks:** 5 (gateway, security, infrastructure, observability, applications)
**Total Services:** 17/17 running (100%)

---

## 📚 Documentation

### Main Guides
- [Architecture](docs/architecture.md) - System design and 8-layer security model
- [Security Layers](docs/security-layers.md) - Defense in depth (10/10 score)
- [Adding Applications](docs/adding-applications.md) - Step-by-step guide for new apps
- [Network Topology](docs/network-topology.md) - Network diagrams and connections

### Security & Gateway Guides
- [Nginx Proxy Manager Guide](docs/npm-guide.md) - NPM configuration and management
- [Cloudflare Tunnel Guide](docs/cloudflare-tunnel-guide.md) - QUIC tunnel setup
- [ModSecurity Tuning](docs/modsecurity-tuning.md) - WAF rules and false positives
- [CrowdSec Management](docs/crowdsec-management.md) - IDS/IPS operations

### Stack Documentation
- [Gateway Layer](stacks/gateway/README.md) - Cloudflare Tunnel
- [Security Layer](stacks/security/README.md) - ModSecurity WAF + CrowdSec IDS/IPS
- [Infrastructure Layer](stacks/infrastructure/README.md) - PostgreSQL, Redis, NPM
- [Observability Layer](stacks/observability/README.md) - Monitoring tools
- [Applications Layer](stacks/applications/README.md) - Application deployment

---

## 🔐 Secrets Management

Secrets are encrypted with **SOPS** and safe to commit to Git.

```bash
# View secrets (decrypt temporarily)
sops --decrypt ansible/group_vars/production/secrets.yml

# Edit secrets (auto-encrypts on save)
sops ansible/group_vars/production/secrets.yml

# Verify it's encrypted
head ansible/group_vars/production/secrets.yml
# verly_db_password: ENC[AES256_GCM,data:xR7...]  ✅
```

**No plaintext secrets in Git!** 🔒

---

## 🎨 Beautiful Portainer UI

All stacks and services are beautifully organized in Portainer with:
- 🏷️ Descriptive labels and categories
- 📊 Resource usage statistics
- 🛡️ Security status indicators
- 📈 Health check status
- 🔗 Layer organization

Access Portainer: `http://portainer.192.168.0.2.nip.io`

---

## 🛠️ Infrastructure Details

### Networks (All Encrypted with IPSec)
- `traefik_public` - Public-facing traffic
- `security_internal` - Security components (Traefik ↔ CrowdSec)
- `postgresql_network` - Database access (apps ↔ PostgreSQL)
- `redis_network` - Cache access (apps ↔ Redis)
- `monitoring_net` - Metrics collection (Prometheus ↔ apps)

### Volumes
- `postgresql_data` - Database (CRITICAL - daily backups)
- `traefik_acme` - SSL certificates
- `grafana_data` - Dashboards
- `prometheus_data` - Metrics (30d retention)
- `crowdsec_data` - Threat intelligence
- `portainer_data` - Docker UI settings

---

## 📊 Performance

**Typical CI/CD Pipeline:**
- Test: ~2min
- Build: ~1min
- Docker build: ~2min
- Deploy + health: ~1min
- **Total: 4-6min** from push to live ⚡

**Spring Boot Startup (ARM64):**
- Cold start: ~35s
- Health ready: ~40s

**WAF Performance:**
- Coraza WASM: ~5ms overhead
- 23x faster than standalone ModSecurity

---

## 🔄 Disaster Recovery

```bash
# Backup all volumes
make backup
# → /home/matt/backups/orange-juice-box/YYYY-MM-DD_HHMMSS/

# Restore from backup
./scripts/restore-volumes.sh /path/to/backup
```

---

## 🤝 Contributing

1. Fork the repository
2. Create branch (`git checkout -b feature/new-feature`)
3. Commit changes (`git commit -am 'Add new feature'`)
4. Push to branch (`git push origin feature/new-feature`)
5. Create Pull Request

---

## 📝 License

MIT License - see [LICENSE](LICENSE)

---

## 🙏 Credits

Developed with ❤️ for Orange Pi ARM64

**Technologies:**
- Docker Swarm
- Traefik v3
- Coraza WAF (WASM)
- CrowdSec
- Ansible
- SOPS (Mozilla)
- Prometheus + Grafana
- Redash
- Spring Boot

---

## 📞 Support

- **Issues**: https://github.com/matttoledo/orange-juice-box/issues
- **Documentation**: [docs/](docs/)

---

**Orange Juice Box** - The concentrated juice of your infrastructure! 🍊📦
