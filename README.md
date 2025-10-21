# 🍊 Orange Juice Box

> Infrastructure as Code para Orange Pi Docker Swarm (ARM64)

**Orange Juice Box** é o repositório centralizado de toda infraestrutura do ambiente Verly, incluindo Docker Swarm stacks, CI/CD templates, e automação com Ansible.

```
🍊 Orange     - Orange Pi hardware (ARM64)
🧃 Juice      - O "suco" da infraestrutura (Docker, Traefik, apps)
📦 Box        - Container que organiza tudo
```

---

## 🏗️ Arquitetura

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

## 📋 Stacks Deployados

| Stack | Serviços | Status |
|-------|----------|--------|
| **security** | Traefik, CrowdSec, ModSecurity, Bouncer, Dashboard | ✅ |
| **monitoring** | Prometheus, Grafana, cAdvisor, Node Exporter | ✅ |
| **verly** | Verly Service API (Spring Boot 3.2.5 + Java 21) | ✅ |
| **postgresql** | PostgreSQL 16 + backups | ✅ |
| **adguard** | AdGuard Home (DNS filtering) | ✅ |
| **portainer** | Portainer CE (Docker UI) | ✅ |

---

## 🚀 Quick Start

### Requisitos

- **Hardware**: ARM64/aarch64 (Orange Pi, Raspberry Pi 4+, AWS Graviton)
- **RAM**: Mínimo 4GB, recomendado 8GB
- **Storage**: SSD recomendado
- **Software**: Ubuntu 20.04+ ARM64, Git, Make

### Instalação

```bash
# 1. Clonar repositório
git clone https://github.com/verlao/orange-juice-box.git
cd orange-juice-box

# 2. Instalar dependências (Ansible, SOPS, age)
make install-deps

# 3. Configurar secrets (primeira vez)
./scripts/generate-secrets.sh
sops ansible/group_vars/production/secrets.yml

# 4. Setup infraestrutura completa
make setup

# 5. Deploy todos os stacks
make deploy-all
```

---

## 🎯 Comandos Principais

```bash
make help                    # Lista todos os comandos
make install-deps            # Instala Ansible, SOPS, age
make setup                   # Setup inicial (Swarm + configs)
make deploy-all              # Deploy todos os stacks
make deploy STACK=verly      # Deploy stack específico
make backup                  # Backup de volumes
make health-check            # Verifica saúde dos serviços
make verify-arm64            # Verifica compatibilidade ARM64
```

---

## 📚 Documentação

### Guias Principais
- [📐 Arquitetura](docs/architecture.md) - Diagrama e visão geral da infra
- [🍊 ARM64 Compatibility](docs/arm64-compatibility.md) - Guia específico ARM64
- [🔐 SOPS Guide](docs/sops-guide.md) - Como gerenciar secrets
- [☕ Java 21 Template](docs/java21-spring-boot-template.md) - Template CI/CD completo
- [🔄 CI/CD Comparison](docs/ci-cd-comparison.md) - Híbrido vs Self-hosted
- [💾 Disaster Recovery](docs/disaster-recovery.md) - Backup e restore
- [📖 Runbook](docs/runbook.md) - Procedimentos operacionais

### Templates
- [Java 21 + Spring Boot](stacks/template-java21/) - Template completo reutilizável

---

## 🔐 Secrets Management

Secrets são criptografados com **SOPS** e seguros para commit no Git.

```bash
# Editar secrets (descriptografa automaticamente no editor)
sops ansible/group_vars/production/secrets.yml

# Verificar que está criptografado
head ansible/group_vars/production/secrets.yml
# postgres_password: ENC[AES256_GCM,data:xR7...]  ✅

# Commit seguro
git add ansible/group_vars/production/secrets.yml
git commit -m "Update secrets"
```

**Nenhum secret em plain text no Git!** 🔒

---

## 🧃 Template: Java 21 + Spring Boot 3.2.5

Template battle-tested para criar novas aplicações com CI/CD completo:

### Stack Técnica
- Java 21 (Eclipse Temurin)
- Spring Boot 3.2.5
- Maven com cache otimizado
- Docker multi-stage build com layers
- ARM64 nativo
- Health checks robustos
- Rollback automático

### Duas Opções de CI/CD

#### 🔀 Híbrido (Padrão)
```yaml
test, build, docker: ubuntu-latest (GitHub)
deploy: self-hosted (Orange Pi)
```
✅ Builds rápidos
✅ Não sobrecarrega Orange Pi
✅ 2000 min/mês grátis
✅ Feedback visual completo no GitHub

#### 🏠 Full Self-hosted
```yaml
test, build, docker, deploy: self-hosted (Orange Pi)
```
✅ 100% privacidade
✅ Minutos ilimitados
✅ Cache Maven persistente
✅ Feedback visual idêntico no GitHub

**Importante:** Ambas opções têm **feedback visual idêntico** no GitHub Actions! A escolha é apenas onde o código executa.

Ver: [docs/ci-cd-comparison.md](docs/ci-cd-comparison.md)

---

## 📊 Performance

**CI/CD típico:**
- Test: ~2min
- Build: ~1min
- Docker build: ~2min
- Deploy + health: ~1min
- **Total: 4-6min** do push ao ar ⚡

**Spring Boot startup (ARM64):**
- Cold start: ~35s
- Health ready: ~40s

---

## 🛠️ Infraestrutura

### Networks
- `traefik_public` - Rede pública exposta
- `security_internal` - Rede interna (CrowdSec, etc)
- Outras redes overlay por stack

### Volumes Principais
- `postgresql_data` - Database
- `traefik_acme` - Certificados SSL
- `grafana_data` - Dashboards
- `prometheus_data` - Métricas
- `crowdsec_data` - Dados de segurança

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
# Backup completo
make backup
# → /home/matt/backups/orange-juice-box/YYYY-MM-DD_HHMMSS/

# Restore (documentado em docs/disaster-recovery.md)
./scripts/restore-volumes.sh /path/to/backup
```

---

## 🎓 Como Criar Nova Aplicação

```bash
# 1. Copiar template
cp -r stacks/template-java21 ~/meu-novo-app/.github

# 2. Ajustar variáveis (SERVICE_NAME, HEALTH_URL)
vim ~/meu-novo-app/.github/workflows/ci-cd-hybrid.yml

# 3. Adicionar ao orange-juice-box
mkdir stacks/meu-novo-app
# ... criar docker-compose.yml

# 4. Push e deploy automático!
git push origin main
```

Ver: [docs/java21-spring-boot-template.md](docs/java21-spring-boot-template.md)

---

## 🤝 Contribuindo

1. Fork do repositório
2. Criar branch (`git checkout -b feature/nova-feature`)
3. Commit changes (`git commit -am 'Add nova feature'`)
4. Push to branch (`git push origin feature/nova-feature`)
5. Criar Pull Request

---

## 📝 Licença

MIT License - veja [LICENSE](LICENSE)

---

## 🙏 Créditos

Desenvolvido com ❤️ para Orange Pi ARM64

**Tecnologias:**
- Docker Swarm
- Ansible
- SOPS (Mozilla)
- Traefik
- CrowdSec
- Prometheus + Grafana
- Spring Boot

---

## 📞 Suporte

- **Issues**: https://github.com/verlao/orange-juice-box/issues
- **Documentação**: [docs/](docs/)
- **Runbook**: [docs/runbook.md](docs/runbook.md)

---

**Orange Juice Box** - O suco concentrado da sua infraestrutura! 🍊📦
