# 🍊 Orange Juice Box

> Infrastructure as Code for Orange Pi Docker Swarm (ARM64)

**Orange Juice Box** is the centralized repository for the entire Verly environment infrastructure, including Docker Swarm stacks, CI/CD templates, and Ansible automation.

```
🍊 Orange     - Orange Pi hardware (ARM64)
🧃 Juice      - The infrastructure "juice" (Docker, Traefik, apps)
📦 Box        - Container that organizes everything
```

---

## 🏗️ Architecture

- **Hardware**: Orange Pi 5 Plus (ARM64/aarch64)
- **OS**: Ubuntu 22.04 LTS ARM64
- **Orchestrator**: Docker Swarm (single-node)
- **Reverse Proxy**: Traefik v3.1
- **Security**: CrowdSec + ModSecurity WAF
- **Monitoring**: Prometheus + Grafana + Dozzle
- **DNS**: AdGuard Home
- **Database**: PostgreSQL 16
- **Secrets**: SOPS + age encryption 🔐
- **CI/CD**: GitHub Actions (self-hosted runner)

---

## 📋 Deployed Stacks

| Stack | Services | Status |
|-------|----------|--------|
| **security** | Traefik, CrowdSec, ModSecurity, Bouncer, Dashboard | ✅ |
| **monitoring** | Prometheus, Grafana, cAdvisor, Node Exporter | ✅ |
| **verly** | Verly Service API (Spring Boot 3.2.5 + Java 21) | ✅ |
| **postgresql** | PostgreSQL 16 + backups | ✅ |
| **adguard** | AdGuard Home (DNS filtering) | ✅ |
| **portainer** | Portainer CE (Docker UI) | ✅ |

---

## 🚀 Quick Start

### Requirements

- **Hardware**: ARM64/aarch64 (Orange Pi, Raspberry Pi 4+, AWS Graviton)
- **RAM**: Minimum 4GB, recommended 8GB
- **Storage**: SSD recommended
- **Software**: Ubuntu 20.04+ ARM64, Git, Make

### Installation

```bash
# 1. Clone repository
git clone https://github.com/matttoledo/orange-juice-box.git
cd orange-juice-box

# 2. Install dependencies (Ansible, SOPS, age)
make install-deps

# 3. Configure secrets (first time)
./scripts/generate-secrets.sh
sops ansible/group_vars/production/secrets.yml

# 4. Setup complete infrastructure
make setup

# 5. Deploy all stacks
make deploy-all
```

---

## 🎯 Main Commands

```bash
make help                    # List all commands
make install-deps            # Install Ansible, SOPS, age
make setup                   # Initial setup (Swarm + configs)
make deploy-all              # Deploy all stacks
make deploy STACK=verly      # Deploy specific stack
make backup                  # Backup volumes
make health-check            # Check services health
make verify-arm64            # Verify ARM64 compatibility
```

---

## 📚 Documentation

### Main Guides
- [📐 Architecture](docs/architecture.md) - Diagram and infrastructure overview
- [🍊 ARM64 Compatibility](docs/arm64-compatibility.md) - ARM64 specific guide
- [🔐 SOPS Guide](docs/sops-guide.md) - How to manage secrets
- [☕ Java 21 Template](docs/java21-spring-boot-template.md) - Complete CI/CD template
- [🔄 CI/CD Comparison](docs/ci-cd-comparison.md) - Hybrid vs Self-hosted
- [💾 Disaster Recovery](docs/disaster-recovery.md) - Backup and restore
- [📖 Runbook](docs/runbook.md) - Operational procedures

### Templates
- [Java 21 + Spring Boot](stacks/template-java21/) - Complete reusable template

---

## 🔐 Secrets Management

Secrets are encrypted with **SOPS** and safe to commit to Git.

```bash
# Edit secrets (automatically decrypts in editor)
sops ansible/group_vars/production/secrets.yml

# Verify it's encrypted
head ansible/group_vars/production/secrets.yml
# postgres_password: ENC[AES256_GCM,data:xR7...]  ✅

# Safe commit
git add ansible/group_vars/production/secrets.yml
git commit -m "Update secrets"
```

**No plaintext secrets in Git!** 🔒

---

## 🧃 Template: Java 21 + Spring Boot 3.2.5

Battle-tested template to create new applications with complete CI/CD:

### Tech Stack
- Java 21 (Eclipse Temurin)
- Spring Boot 3.2.5
- Maven with optimized cache
- Docker multi-stage build with layers
- Native ARM64
- Robust health checks
- Automatic rollback

### Two CI/CD Options

#### 🔀 Hybrid (Default)
```yaml
test, build, docker: ubuntu-latest (GitHub)
deploy: self-hosted (Orange Pi)
```
✅ Fast builds
✅ Doesn't overload Orange Pi
✅ 2000 min/month free
✅ Complete visual feedback on GitHub

#### 🏠 Full Self-hosted
```yaml
test, build, docker, deploy: self-hosted (Orange Pi)
```
✅ 100% privacy
✅ Unlimited minutes
✅ Persistent Maven cache
✅ Identical visual feedback on GitHub

**Important:** Both options have **identical visual feedback** on GitHub Actions! The choice is only where the code runs.

See: [docs/ci-cd-comparison.md](docs/ci-cd-comparison.md)

---

## 📊 Performance

**Typical CI/CD:**
- Test: ~2min
- Build: ~1min
- Docker build: ~2min
- Deploy + health: ~1min
- **Total: 4-6min** from push to live ⚡

**Spring Boot startup (ARM64):**
- Cold start: ~35s
- Health ready: ~40s

---

## 🛠️ Infrastructure

### Networks
- `traefik_public` - Public exposed network
- `security_internal` - Internal network (CrowdSec, etc)
- Other overlay networks per stack

### Main Volumes
- `postgresql_data` - Database
- `traefik_acme` - SSL certificates
- `grafana_data` - Dashboards
- `prometheus_data` - Metrics
- `crowdsec_data` - Security data

### Firewall (UFW)
```
22/tcp    - SSH (LAN only)
80/tcp    - HTTP Traefik
443/tcp   - HTTPS Traefik
53        - DNS AdGuard
3000/tcp  - Grafana (LAN only)
9000/tcp  - Portainer (LAN only)
```

---

## 🔄 Disaster Recovery

```bash
# Complete backup
make backup
# → /home/matt/backups/orange-juice-box/YYYY-MM-DD_HHMMSS/

# Restore (documented in docs/disaster-recovery.md)
./scripts/restore-volumes.sh /path/to/backup
```

---

## 🎓 How to Create New Application

```bash
# 1. Copy template
cp -r stacks/template-java21 ~/my-new-app/.github

# 2. Adjust variables (SERVICE_NAME, HEALTH_URL)
vim ~/my-new-app/.github/workflows/ci-cd-hybrid.yml

# 3. Add to orange-juice-box
mkdir stacks/my-new-app
# ... create docker-compose.yml

# 4. Push and automatic deploy!
git push origin main
```

See: [docs/java21-spring-boot-template.md](docs/java21-spring-boot-template.md)

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
- Ansible
- SOPS (Mozilla)
- Traefik
- CrowdSec
- Prometheus + Grafana
- Spring Boot

---

## 📞 Support

- **Issues**: https://github.com/matttoledo/orange-juice-box/issues
- **Documentation**: [docs/](docs/)
- **Runbook**: [docs/runbook.md](docs/runbook.md)

---

**Orange Juice Box** - The concentrated juice of your infrastructure! 🍊📦
