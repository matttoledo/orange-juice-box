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
- **Reverse Proxy**: Traefik v3.1
- **WAF**: Coraza (WASM, 23x faster than ModSecurity)
- **Security**: CrowdSec + Rate Limiting + Security Headers
- **Monitoring**: Prometheus + Grafana
- **Data Visualization**: Redash
- **Database**: PostgreSQL 16
- **Secrets**: SOPS + age encryption
- **CI/CD**: GitHub Actions (self-hosted runner)

---

## 📦 Layer Organization

Infrastructure is organized in **4 clean layers** by responsibility:

```
stacks/
├── security/           Security Layer - WAF, Traefik, CrowdSec
├── infrastructure/     Infrastructure Layer - PostgreSQL, Redis
├── observability/      Observability Layer - Grafana, Prometheus, Redash
└── applications/       Applications Layer - Verly Service + your apps
```

### Layer 1: Security
**Services:** Traefik, CrowdSec, CrowdSec Bouncer, CrowdSec Dashboard

**Responsibility:** Reverse proxy, WAF, threat detection, SSL/TLS termination

### Layer 2: Infrastructure
**Services:** PostgreSQL 16, Redis

**Responsibility:** Shared data services (databases, caching, message queues)

### Layer 3: Observability
**Services:** Grafana, Prometheus, Redash, Dozzle, Portainer, cAdvisor, Node Exporter

**Responsibility:** Monitoring, metrics, logs, dashboards, container management

### Layer 4: Applications
**Services:** Verly Service (+ your applications)

**Responsibility:** Business logic, APIs, microservices

---

## 🛡️ Automatic Protection

### Public Applications (Internet-facing)

All public apps get **automatic full protection** with zero configuration:

```
Internet → WAF → Rate Limit → CrowdSec → Headers → Your App
```

**Protection includes:**
- ✅ **WAF** - Coraza WASM with OWASP Core Rule Set (SQLi, XSS, RCE, LFI protection)
- ✅ **Rate Limiting** - 50 requests/min (burst 25) to prevent DDoS
- ✅ **CrowdSec** - 17,000+ malicious IPs blocked automatically
- ✅ **Security Headers** - HSTS, CSP, XSS Protection, Clickjacking prevention
- ✅ **Container Hardening** - OWASP Docker Top 10 compliant

**Usage:** Just add one line to your docker-compose.yml:
```yaml
- "traefik.http.routers.my-app.middlewares=auto-public-protection@file"
```

### Internal Applications (LAN-only)

Internal apps have **zero middlewares** for maximum performance:

```
LAN → Your App (direct)
```

**Protection:**
- ✅ **UFW Firewall** - Blocks external access to internal ports
- ✅ **Traefik Routing** - Only responds to `.nip.io` domains
- ✅ **Network Segmentation** - Isolated Docker networks
- ❌ NO WAF, NO Rate Limiting, NO Middlewares (trusted LAN)

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
| **Verly Service** | Public API | https://api.verlyvidracaria.com | WAF + Rate Limit + CrowdSec + Headers |
| **Grafana** | Dashboard | http://grafana.192.168.0.2.nip.io | None (LAN only) |
| **Prometheus** | Metrics | http://prometheus.192.168.0.2.nip.io | None (LAN only) |
| **Redash** | Data Viz | http://redash.192.168.0.2.nip.io | None (LAN only) |
| **Dozzle** | Logs | http://dozzle.192.168.0.2.nip.io | None (LAN only) |
| **Portainer** | Docker UI | http://portainer.192.168.0.2.nip.io | None (LAN only) |

---

## 📚 Documentation

### Main Guides
- [Architecture](docs/architecture.md) - System design and layer organization
- [Security Layers](docs/security-layers.md) - Defense in depth explanation
- [Adding Applications](docs/adding-applications.md) - Step-by-step guide for new apps
- [Network Topology](docs/network-topology.md) - Network diagrams and connections

### Stack Documentation
- [Security Layer](stacks/security/README.md) - Traefik, WAF, CrowdSec
- [Infrastructure Layer](stacks/infrastructure/README.md) - PostgreSQL, Redis
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
