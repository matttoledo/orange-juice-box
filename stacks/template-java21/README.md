# ☕ Template: Java 21 + Spring Boot 3.2.5

Template battle-tested para criar aplicações Spring Boot com CI/CD completo para Orange Juice Box.

## 🎯 O que está incluído

✅ **GitHub Actions CI/CD** (2 opções: híbrido e self-hosted)
✅ **Docker multi-stage** otimizado para ARM64
✅ **Spring Boot Actuator** com health checks
✅ **Prometheus metrics** integrado
✅ **Testes paralelos** (Surefire configurado)
✅ **Rollback automático** em caso de falha
✅ **Zero-downtime deploy**
✅ **Traefik labels** prontos

---

## 🚀 Quick Start

### 1. Copiar Template para Novo Projeto

```bash
# Criar novo projeto
mkdir meu-novo-app && cd meu-novo-app
git init

# Copiar arquivos do template
cp -r ~/orange-juice-box/stacks/template-java21/.github .
cp ~/orange-juice-box/stacks/template-java21/Dockerfile.ci .
cp ~/orange-juice-box/stacks/template-java21/docker-compose.yml .
cp ~/orange-juice-box/stacks/template-java21/pom.xml.template pom.xml
cp ~/orange-juice-box/stacks/template-java21/.env.example .env
mkdir -p src/{main/resources,test/resources}
cp ~/orange-juice-box/stacks/template-java21/src/main/resources/application.yml src/main/resources/
cp ~/orange-juice-box/stacks/template-java21/src/test/resources/application-test.yml src/test/resources/
```

### 2. Escolher CI/CD

```bash
# Opção A: Híbrido (padrão, recomendado)
cp .github/workflows/ci-cd-hybrid.yml .github/workflows/ci-cd.yml
rm .github/workflows/ci-cd-selfhosted.yml

# OU

# Opção B: Full self-hosted
cp .github/workflows/ci-cd-selfhosted.yml .github/workflows/ci-cd.yml
rm .github/workflows/ci-cd-hybrid.yml
```

Ver: [../../docs/ci-cd-comparison.md](../../docs/ci-cd-comparison.md)

### 3. Ajustar Variáveis

#### `.github/workflows/ci-cd.yml`

```yaml
# Linha ~68: Nome do serviço no Docker Swarm
SERVICE_NAME="seu_stack_seu-service"

# Linha ~76: URL do health check
HEALTH_URL="http://192.168.0.2/seu-app/actuator/health"
```

#### `pom.xml`

```xml
<!-- Linha ~11: Seu projeto -->
<groupId>com.sua.empresa</groupId>
<artifactId>seu-servico</artifactId>
<name>seu-servico</name>

<!-- Linha ~168: Classe main -->
<mainClass>com.sua.empresa.Application</mainClass>
```

#### `docker-compose.yml`

```yaml
# Linha 4: Nome do serviço
seu-servico:

# Linha 5: Imagem no GHCR
image: ghcr.io/seu-usuario/seu-servico:latest

# Linha 19: Healthcheck path
"http://localhost:8080/seu-app/actuator/health"

# Linha 35: Traefik rule
- traefik.http.routers.seu-app.rule=Host(`api.seudominio.com`)
```

#### `application.yml`

```yaml
# Linha 3: Context path
context-path: /seu-app

# Linha 22: Nome da aplicação
name: seu-servico
```

#### `.env`

```bash
POSTGRES_DB=seu_db
POSTGRES_USER=seu_usuario
POSTGRES_PASSWORD=senha_segura_aqui
JWT_SECRET=chave_jwt_muito_longa
CONTEXT_PATH=/seu-app
```

### 4. Setup GitHub

```bash
# Criar repo no GitHub
gh repo create seu-usuario/seu-servico --private

# Configurar remote
git remote add origin git@github.com:seu-usuario/seu-servico.git

# Settings → Actions → General
# Workflow permissions → Read and write permissions ✅
```

### 5. Deploy Inicial (Manual)

```bash
# Copiar .env.example para .env e preencher valores
cp .env.example .env
vim .env

# Deploy stack pela primeira vez
docker stack deploy -c docker-compose.yml seu_stack

# Verificar
docker service ls | grep seu_stack
docker service logs seu_stack_seu-service
```

### 6. Habilitar CI/CD

```bash
# Push para prod → deploy automático!
git add .
git commit -m "Initial commit"
git push origin prod

# Acompanhar no GitHub Actions
# → test, build, docker, deploy
# → ~6 minutos total
```

---

## 🔧 Customizações Comuns

### Adicionar Dependência

```xml
<!-- pom.xml -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-security</artifactId>
</dependency>
```

### Adicionar Banco de Dados Diferente

```xml
<!-- MySQL em vez de PostgreSQL -->
<dependency>
    <groupId>com.mysql</groupId>
    <artifactId>mysql-connector-j</artifactId>
</dependency>
```

```yaml
# application.yml
spring:
  datasource:
    url: jdbc:mysql://${MYSQL_HOST}:3306/${MYSQL_DB}
  jpa:
    database-platform: org.hibernate.dialect.MySQLDialect
```

### Ajustar Recursos

```yaml
# docker-compose.yml
deploy:
  resources:
    limits:
      memory: 2G      # Aumentar se app precisa mais RAM
    reservations:
      memory: 1.5G
```

### Múltiplas Réplicas

```yaml
# docker-compose.yml
deploy:
  replicas: 2        # Antes: 1

# CI/CD workflow ajustar:
--update-parallelism 1  # Atualiza 1 réplica por vez
```

---

## 🏥 Troubleshooting

### Deploy Falha: "Service not found"

**Problema:** Serviço não existe no Docker Swarm

**Solução:**
```bash
# Deploy manual primeira vez
docker stack deploy -c docker-compose.yml seu_stack

# Verificar
docker service ls | grep seu_stack
```

### Health Check Falha

**Problema:** `/actuator/health` retorna 404 ou 500

**Verificar:**
```bash
# Logs do serviço
docker service logs seu_stack_seu-service

# Testar endpoint
curl http://192.168.0.2/seu-app/actuator/health

# Verificar application.yml
cat src/main/resources/application.yml | grep -A 5 "management:"
```

**Solução comum:**
```yaml
# application.yml - verificar que está assim:
management:
  endpoints:
    web:
      exposure:
        include: health
  endpoint:
    health:
      enabled: true
```

### Rollback Automático Ocorre

**Problema:** Deploy funciona mas depois faz rollback

**Investigar:**
```bash
# Ver logs do serviço durante deploy
docker service logs -f seu_stack_seu-service

# Verificar update status
docker service inspect seu_stack_seu-service --format='{{json .UpdateStatus}}' | jq
```

**Causas comuns:**
- Health check falha após 30s
- Container crashando
- Dependência não disponível (banco, Redis, etc)

### Build Lento

**Problema:** Maven build demora >5 minutos

**Solução:**
```bash
# Usar self-hosted runner (cache Maven persistente)
# Ou
# Otimizar testes (remover sleeps, usar H2 in-memory)
```

---

## 📊 Métricas de Sucesso

Após setup correto, você deve ter:

✅ **CI/CD**: Push → 6min → Deploy automático
✅ **Tests**: 100+ testes em <2min
✅ **Health**: Endpoint responde 200 + "UP"
✅ **Rollback**: Funciona automaticamente em falha
✅ **Logs**: Visíveis no GitHub Actions
✅ **Monitoring**: Prometheus scraping /actuator/prometheus

---

## 📚 Arquivos do Template

```
template-java21/
├── README.md                       ← Este arquivo
├── .github/workflows/
│   ├── ci-cd-hybrid.yml            ← Padrão
│   └── ci-cd-selfhosted.yml        ← Alternativa
├── Dockerfile.ci                   ← Multi-stage ARM64
├── docker-compose.yml              ← Stack deployment
├── pom.xml.template                ← Maven config
├── .env.example                    ← Environment vars
└── src/
    ├── main/resources/
    │   └── application.yml         ← Spring config
    └── test/resources/
        └── application-test.yml    ← Test config (H2)
```

---

## 🎓 Exemplo Real

Este template foi extraído do **verly-service** que roda em produção com:
- 212 testes unitários e integração
- Deploy automático diário
- Zero-downtime deployments
- Health checks robustos
- Rollback testado em produção

**Confiável e testado!** ✅

---

## 📖 Ver Também

- [Java 21 Spring Boot Guide](../../docs/java21-spring-boot-template.md)
- [CI/CD Comparison](../../docs/ci-cd-comparison.md)
- [ARM64 Compatibility](../../docs/arm64-compatibility.md)

---

**Orange Juice Box** ☕🍊 - Template pronto para produção!
