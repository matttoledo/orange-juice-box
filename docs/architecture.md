# 🏗️ Orange Juice Box - Arquitetura

## Visão Geral

Orange Juice Box é a infraestrutura completa rodando em um Orange Pi 5 Plus com Docker Swarm, otimizada para ARM64.

```
┌─────────────────────────────────────────────────────────────────────┐
│                        INTERNET                                     │
│                           │                                         │
│                    ┌──────▼──────┐                                  │
│                    │  Cloudflare │                                  │
│                    │   Tunnel    │                                  │
│                    └──────┬──────┘                                  │
└───────────────────────────┼─────────────────────────────────────────┘
                            │
                     ┌──────▼──────┐
                     │   Traefik   │ :80, :443
                     │   (v3.1)    │
                     └──────┬──────┘
                            │
            ┌───────────────┼───────────────┐
            │               │               │
      ┌─────▼─────┐   ┌────▼────┐    ┌────▼────┐
      │ CrowdSec  │   │   Verly │    │ Grafana │
      │  Bouncer  │   │ Service │    │Dashboard│
      └─────┬─────┘   └────┬────┘    └────┬────┘
            │              │              │
      ┌─────▼─────┐   ┌────▼────┐    ┌────▼────┐
      │ CrowdSec  │   │PostgreSQL│   │Prometheus│
      │  Engine   │   └─────────┘    └────┬────┘
      └───────────┘                        │
                                      ┌────▼────┐
                                      │cAdvisor │
                                      │  Node   │
                                      │Exporter │
                                      └─────────┘
```

---

## 🐳 Docker Swarm Topology

```
Orange Pi 5 Plus (Manager + Worker)
├── security_traefik (1 replica)
├── security_crowdsec (1 replica)
├── security_bouncer-traefik (1 replica)
├── security_crowdsec-dashboard (1 replica)
├── security_modsecurity (1 replica)
├── verly_verly-service (1 replica)
├── postgresql_postgresql (1 replica)
├── swarm-monitoring_grafana (1 replica)
├── swarm-monitoring_prometheus (1 replica)
├── swarm-monitoring_cadvisor (global)
├── swarm-monitoring_node-exporter (global)
├── adguard_adguard (1 replica)
└── portainer (1 replica)
```

**Placement Constraints:**
- Manager-only services: Traefik, CrowdSec
- Global services: cAdvisor, node-exporter

---

## 🌐 Networks

```
traefik_public (overlay)
├── Traefik
├── Verly Service
├── Grafana
├── CrowdSec Dashboard
├── AdGuard
└── Portainer

security_internal (overlay)
├── Traefik
├── CrowdSec
├── CrowdSec Bouncer
└── ModSecurity

swarm-monitoring_net (overlay)
├── Prometheus
├── Grafana
├── cAdvisor
└── node-exporter

postgresql_network (overlay)
├── PostgreSQL
└── Verly Service

Outras redes isoladas por stack
```

---

## 🔒 Security Layers

### Layer 1: Network (UFW)
```
Firewall Rules:
- SSH: LAN only (192.168.0.0/24)
- HTTP/HTTPS: Public (80, 443)
- DNS: Public (53, 853)
- Dashboards: LAN only (3000, 8888, 9000, 9091)
```

### Layer 2: Application (Traefik + CrowdSec)
```
Request Flow:
Internet → Traefik → CrowdSec Bouncer → WAF → App

Middlewares:
- CrowdSec: Block IPs maliciosos
- Rate Limiting: 100 req/min (geral), 50 req/min (API)
- Security Headers: HSTS, CSP, X-Frame-Options
- ModSecurity: WAF OWASP CRS (paranoia level 2)
```

### Layer 3: Container (Docker)
```
- Non-root users
- Read-only root filesystem (onde possível)
- Resource limits (CPU, memory)
- Health checks
```

### Layer 4: Application (Spring Security + JWT)
```
- JWT authentication
- Role-based access control
- Password hashing (BCrypt)
- CSRF protection
```

---

## 📊 Monitoring Stack

### Metrics Collection
```
Apps → Prometheus ← cAdvisor (container metrics)
                  ← node-exporter (host metrics)
                  ← Spring Actuator (app metrics)
```

### Visualization
```
Prometheus → Grafana Dashboards
          → Alertmanager → Notifications
```

### Logs
```
Containers → Docker logs → Dozzle (web viewer)
          → CrowdSec (security analysis)
```

---

## 💾 Data Persistence

### Volumes
```
postgresql_data              # Database (CRITICAL - backup diário)
traefik_acme                 # SSL certificates (backup semanal)
grafana_data                 # Dashboards (backup semanal)
prometheus_data              # Métricas (30d retention)
crowdsec_data                # Security data
adguard_config               # DNS config
portainer_data               # Portainer settings
```

### Backup Strategy
```
Diário:   PostgreSQL (automático via cron)
Semanal:  Traefik ACME, Grafana
Mensal:   Full backup de todos os volumes
```

---

## 🚀 CI/CD Pipeline

### Verly Service (Exemplo Real)
```
GitHub Push (prod)
    │
    ├─ test (ubuntu-latest)         # 212 testes em 2min
    ├─ build (ubuntu-latest)        # Maven package 1min
    ├─ docker (ubuntu-latest)       # Build ARM64 image 2min
    │                               # Push para ghcr.io
    └─ deploy (self-hosted)         # Orange Pi
        ├─ Pull image
        ├─ Update service (zero-downtime)
        ├─ Wait for healthy (Docker health check)
        ├─ Verify HTTP health (actuator/health)
        └─ Rollback if failed ✅
```

**Total:** 4-6 minutos do push ao deploy

Ver: [docs/java21-spring-boot-template.md](docs/java21-spring-boot-template.md)

---

## 🍊 ARM64 Considerations

Todas as imagens usam **manifest lists** do Docker Hub que automaticamente detectam ARM64.

### Imagens Verificadas (ARM64 OK)
- ✅ Traefik v3.1
- ✅ PostgreSQL 16-alpine
- ✅ Grafana (oficial)
- ✅ Prometheus (oficial)
- ✅ CrowdSec (oficial)
- ✅ AdGuard Home
- ✅ Portainer CE
- ✅ Eclipse Temurin JRE 21

### Performance ARM64
- Eficiência energética superior
- Spring Boot: performance similar a x86_64
- PostgreSQL: performance similar a x86_64
- Docker build: pode ser mais lento que x86_64 (mas otimizado com cache)

Ver: [docs/arm64-compatibility.md](docs/arm64-compatibility.md)

---

## 🔄 Update Strategy

### Stack Updates (Ansible)
```bash
# Atualizar configuração de stack
make deploy STACK=monitoring

# Rollback (Git)
git revert HEAD
make deploy STACK=monitoring
```

### Application Updates (CI/CD)
```
Automático via GitHub Actions:
- Push para prod → Deploy automático
- Rollback automático se falhar
- Zero-downtime (start-first strategy)
```

---

## 📈 Scalability

**Atual:** Single-node Swarm
**Futuro:** Multi-node Swarm
```
Manager Node: Orange Pi 5 Plus
Worker Nodes: Adicionar novos Orange Pi ou Raspberry Pi

ansible/playbooks/add-worker.yml  # Playbook pronto
```

---

## 🎯 Best Practices Implementadas

✅ Infrastructure as Code (Git)
✅ Secrets criptografados (SOPS)
✅ Zero-downtime deployments
✅ Rollback automático
✅ Health checks robustos
✅ Monitoring completo
✅ Security hardening (UFW, SSH, CrowdSec)
✅ Backup automatizado
✅ CI/CD com GitHub Actions
✅ Self-hosted runner (ARM64)
✅ Multi-stage Docker builds com layers
✅ Resource limits nos containers

---

## 📚 Próximos Passos

Ver [docs/runbook.md](docs/runbook.md) para:
- Procedimentos operacionais
- Troubleshooting
- Manutenção rotineira
- Adição de novos serviços
- Scaling para multi-node

---

**Última atualização:** 2025-10-19
