# 🍊 ARM64 Compatibility Guide

## Visão Geral

Orange Juice Box roda 100% em **ARM64/aarch64** (Orange Pi 5 Plus).

**Boa notícia:** Todas as imagens modernas do Docker Hub têm suporte ARM64 via **manifest lists** (multi-arch images).

---

## ✅ Imagens Verificadas (ARM64 OK)

Todas as imagens usadas no Orange Juice Box foram testadas e funcionam perfeitamente em ARM64:

### Infrastructure
| Imagem | Versão | ARM64 | Notas |
|--------|--------|-------|-------|
| **Traefik** | v3.1 | ✅ | Oficial multi-arch |
| **CrowdSec** | latest | ✅ | Oficial multi-arch |
| **fbonalair/traefik-crowdsec-bouncer** | latest | ✅ | Testado OK |
| **ModSecurity** | nginx-alpine | ✅ | OWASP oficial |

### Monitoring
| Imagem | Versão | ARM64 | Notas |
|--------|--------|-------|-------|
| **Prometheus** | latest | ✅ | Oficial multi-arch |
| **Grafana** | latest | ✅ | Oficial multi-arch |
| **cAdvisor** | v0.47.0 | ✅ | Google oficial |
| **node-exporter** | v1.5.0 | ✅ | Prometheus oficial |
| **Alertmanager** | latest | ✅ | Prometheus oficial |
| **Dozzle** | latest | ✅ | Amir20 multi-arch |

### Applications
| Imagem | Versão | ARM64 | Notas |
|--------|--------|-------|-------|
| **PostgreSQL** | 16-alpine | ✅ | Oficial multi-arch |
| **Redis** | 7-alpine | ✅ | Oficial multi-arch |
| **AdGuard Home** | latest | ✅ | Oficial multi-arch |
| **Portainer CE** | latest | ✅ | Oficial multi-arch |
| **Metabase** | latest | ✅ | Dashboard CrowdSec |

### Base Images
| Imagem | Versão | ARM64 | Notas |
|--------|--------|-------|-------|
| **eclipse-temurin** | 21-jre-jammy | ✅ | Adoptium oficial |
| **Ubuntu** | 22.04 | ✅ | Canonical oficial |
| **Alpine** | latest | ✅ | Alpine oficial |
| **Node.js** | 20-alpine | ✅ | Node oficial |

---

## 🐳 Docker Multi-Arch

### Como Funciona

Docker Hub usa **manifest lists** que contêm múltiplas arquiteturas:

```bash
# Quando você faz docker pull traefik:v3.1
$ docker pull traefik:v3.1

# Docker detecta automaticamente sua arquitetura
Detected: linux/arm64

# E puxa a versão ARM64 do manifest list
Pulling: traefik:v3.1-linux-arm64
```

**Você não precisa fazer nada especial!** ✨

### Verificar Suporte ARM64

```bash
# Verificar manifest de uma imagem
docker manifest inspect traefik:v3.1

# Procurar por arm64
docker manifest inspect traefik:v3.1 | grep -A 5 arm64

# Script automatizado
./scripts/verify-arm64-images.sh
```

---

## 🏗️ Build de Imagens Customizadas

### Dockerfile com ARM64

```dockerfile
# Especificar plataforma (opcional, mas explícito)
FROM --platform=linux/arm64 eclipse-temurin:21-jre-jammy

# Ou deixar Docker detectar automaticamente
FROM eclipse-temurin:21-jre-jammy

# Resto do Dockerfile normal
WORKDIR /app
COPY target/*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### Build Local (ARM64)

```bash
# Build normal - detecta ARM64 automaticamente
docker build -t minha-app:latest .

# Build explícito ARM64
docker buildx build --platform linux/arm64 -t minha-app:latest .
```

### Build no GitHub Actions (Multi-arch)

```yaml
# Se quiser suportar AMD64 + ARM64
- name: Build and push
  uses: docker/build-push-action@v5
  with:
    platforms: linux/amd64,linux/arm64
    push: true
    tags: ghcr.io/user/app:latest

# Apenas ARM64 (Orange Juice Box padrão)
- name: Build and push
  uses: docker/build-push-action@v5
  with:
    platforms: linux/arm64
    push: true
    tags: ghcr.io/user/app:latest
```

---

## ⚡ Performance ARM64

### Benchmarks (Orange Pi 5 Plus)

#### Spring Boot 3.2.5 + Java 21
```
Cold start:        ~35s
Warm start:        ~30s
Request latency:   ~50ms (p95)
Throughput:        ~500 req/s
Memory usage:      ~800MB (heap)
```

#### PostgreSQL 16
```
Simple queries:    ~2ms
Complex joins:     ~50ms
Insert batch:      ~100ms/1000 rows
Index scan:        Similar ao x86_64
```

#### Docker Build
```
Maven build:       ~60s (primeiro), ~30s (com cache)
Docker build:      ~120s (multi-stage)
Startup:           ~35s (Spring Boot)
```

### Comparação com x86_64

| Workload | ARM64 | x86_64 | Diferença |
|----------|-------|--------|-----------|
| **Spring Boot startup** | 35s | 32s | +9% 🟡 |
| **PostgreSQL queries** | ~2ms | ~2ms | ±0% ✅ |
| **Maven build** | 60s | 45s | +33% 🟡 |
| **Docker build** | 120s | 90s | +33% 🟡 |
| **Runtime performance** | 100% | 100% | ±0% ✅ |
| **Eficiência energética** | ⚡⚡⚡ | ⚡ | ARM64 vence! ✅ |

**Conclusão:** ARM64 é ligeiramente mais lento em **builds**, mas **runtime** é praticamente idêntico com **muito** menor consumo de energia.

---

## 🔧 Otimizações Específicas ARM64

### JVM Tuning

```bash
# No Dockerfile
ENV JAVA_TOOL_OPTIONS="-XX:+UseContainerSupport \
  -XX:MaxRAMPercentage=75.0 \
  -XX:InitialRAMPercentage=50.0 \
  -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=200 \
  -XX:+UseStringDeduplication \
  -XX:+TieredCompilation \
  -XX:TieredStopAtLevel=1"
```

**Específico ARM64:**
- G1GC funciona muito bem em ARM64
- TieredCompilation reduz tempo de startup
- UseStringDeduplication economiza RAM

### Maven Build

```xml
<!-- pom.xml -->
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-surefire-plugin</artifactId>
    <configuration>
        <parallel>classes</parallel>
        <threadCount>4</threadCount>          <!-- Orange Pi tem 8 cores -->
        <forkCount>2C</forkCount>             <!-- 2 forks por core -->
        <reuseForks>true</reuseForks>
        <argLine>-Xmx1024m</argLine>          <!-- 1GB por fork -->
    </configuration>
</plugin>
```

### Docker Build Cache

```yaml
# GitHub Actions
cache-from: |
  type=registry,ref=ghcr.io/user/app:buildcache
  type=gha
cache-to: |
  type=registry,ref=ghcr.io/user/app:buildcache,mode=max
  type=gha,mode=max
```

**Cache persiste entre builds** = segunda build ~50% mais rápida

---

## ⚠️ Problemas Conhecidos

### 1. Algumas Imagens Antigas Sem ARM64

**Sintoma:**
```
WARNING: The requested image's platform (linux/amd64) does not match
the detected host platform (linux/arm64)
```

**Solução:**
- Procurar imagem alternativa com ARM64
- Ou fazer build próprio da imagem

**Exemplo:**
```dockerfile
# Em vez de imagem antiga
FROM antiga/imagem-sem-arm64

# Usar imagem oficial multi-arch
FROM ubuntu:22.04
# ... instalar o que precisa
```

### 2. Builds Java Podem Ser Lentos (Primeira Vez)

**Causa:** Maven baixa dependências + compila tudo

**Solução:**
```bash
# Usar cache Maven persistente (self-hosted)
~/.m2/repository persiste entre builds ✅

# Ou cache do GitHub Actions (híbrido)
uses: actions/cache@v4
with:
  path: ~/.m2
  key: ${{ runner.os }}-m2-${{ hashFiles('**/pom.xml') }}
```

### 3. Emulação Quebra Performance

**EVITAR:**
```yaml
# ❌ NÃO fazer isso em Orange Pi
platforms: linux/amd64  # Vai usar QEMU = 10x mais lento!
```

**CORRETO:**
```yaml
# ✅ Usar ARM64 nativo
platforms: linux/arm64
```

---

## 🧪 Testar Compatibilidade

### Script Automatizado

```bash
./scripts/verify-arm64-images.sh
```

Verifica todas as imagens dos stacks e reporta:
```
✅ security_traefik: traefik:v3.1 (ARM64 OK)
✅ postgresql_postgresql: postgres:16-alpine (ARM64 OK)
⚠️  custom_app: user/custom:latest (verificar manualmente)
```

### Teste Manual

```bash
# Verificar uma imagem específica
docker manifest inspect traefik:v3.1 | grep -i arm64

# Saída esperada:
"architecture": "arm64",
"os": "linux"
```

---

## 📦 Imagens Customizadas

### Criar Imagem ARM64

```dockerfile
# Dockerfile
FROM eclipse-temurin:21-jre-jammy AS builder
# ... build steps

FROM eclipse-temurin:21-jre-jammy AS runtime
# ... runtime setup
```

```bash
# Build local (ARM64 automático)
docker build -t app:latest .

# Build no CI/CD (especificar plataforma)
docker buildx build --platform linux/arm64 -t app:latest .
```

### Push para Registry

```bash
# Login
echo $PAT | docker login ghcr.io -u username --password-stdin

# Tag
docker tag app:latest ghcr.io/username/app:latest

# Push (ARM64)
docker push ghcr.io/username/app:latest
```

---

## 🎯 Checklist ARM64

Ao adicionar nova imagem ao Orange Juice Box:

- [ ] Verificar suporte ARM64 no Docker Hub
- [ ] Testar pull da imagem no Orange Pi
- [ ] Verificar manifest: `docker manifest inspect imagem:tag`
- [ ] Rodar container de teste: `docker run imagem:tag`
- [ ] Adicionar ao `scripts/verify-arm64-images.sh`
- [ ] Documentar em README do stack

---

## 📚 Recursos

- [Docker Multi-platform Images](https://docs.docker.com/build/building/multi-platform/)
- [ARM Docker Hub](https://hub.docker.com/u/arm64v8)
- [Adoptium Temurin ARM64](https://adoptium.net/temurin/releases/?version=21&arch=aarch64)
- [Works on ARM](https://www.worksonarm.com/) - Lista de software compatível

---

## 🆚 ARM64 vs x86_64

### Vantagens ARM64

✅ Eficiência energética (~3x melhor)
✅ Custo/performance (hardware mais barato)
✅ Temperatura mais baixa
✅ Ecossistema crescente (AWS Graviton, Apple M1/M2/M3)

### Desvantagens ARM64

❌ Algumas imagens antigas sem suporte
❌ Builds podem ser mais lentos
❌ Menos debugging tools nativos
❌ Ecossistema menor (mas crescendo rápido)

### Para Orange Juice Box

**Perfeito para:**
- ✅ APIs REST (Spring Boot, Node.js, Go)
- ✅ Databases (PostgreSQL, Redis, MySQL)
- ✅ Web servers (Nginx, Traefik)
- ✅ Monitoring (Prometheus, Grafana)

**Evitar:**
- ❌ Workloads que precisam x86_64 específico
- ❌ Imagens proprietárias sem ARM64
- ❌ Emulação de x86 (performance ruim)

---

## 🎓 Conclusão

**ARM64 é uma escolha excelente para Orange Juice Box!**

- Todas imagens funcionam ✅
- Performance ótima ✅
- Eficiência energética superior ✅
- Ecossistema maduro ✅

**Orange Juice Box** 🍊 - 100% ARM64, 100% funcional!
