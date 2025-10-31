# ☕ Java 21 + Spring Boot 3.2.5 - Template CI/CD

## 📋 Template Completo

Template battle-tested extraído do **verly-service** com 212 testes em produção.

**Stack:**
- Java 21 (Eclipse Temurin)
- Spring Boot 3.2.5
- Maven 3.x
- Docker multi-stage com layers
- ARM64 otimizado
- Health checks robustos
- Rollback automático

---

## 🚀 Quick Start

```bash
# 1. Copiar template para novo projeto
cp -r orange-juice-box/stacks/template-java21/* ~/meu-novo-app/

# 2. Escolher CI/CD (híbrido ou self-hosted)
cp template-java21/.github/workflows/ci-cd-hybrid.yml ~/meu-novo-app/.github/workflows/ci-cd.yml

# 3. Ajustar variáveis
vim ~/meu-novo-app/.github/workflows/ci-cd.yml
# - SERVICE_NAME
# - HEALTH_URL
# - SPRING_APP_NAME

# 4. Ajustar pom.xml
vim ~/meu-novo-app/pom.xml
# - groupId, artifactId
# - mainClass

# 5. Push e pronto!
git push origin prod
# → Deploy automático em 4-6 minutos
```

---

## 📄 Arquivo 1: `.github/workflows/ci-cd-hybrid.yml`

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop, prod ]
    paths:
      - 'src/**'
      - 'pom.xml'
      - 'Dockerfile*'
      - '.github/workflows/**'
  pull_request:
    branches: [ main, prod ]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    name: Run Tests
    runs-on: ubuntu-latest
    permissions:
      contents: read
      checks: write

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Set up JDK 21
      uses: actions/setup-java@v4
      with:
        java-version: '21'
        distribution: 'temurin'
        cache: maven

    - name: Cache Maven dependencies
      uses: actions/cache@v4
      with:
        path: ~/.m2
        key: ${{ runner.os }}-m2-${{ hashFiles('**/pom.xml') }}
        restore-keys: ${{ runner.os }}-m2

    - name: Run tests
      run: mvn clean verify -DskipSpotless=true
      env:
        SPRING_PROFILES_ACTIVE: test

    - name: Generate test report
      uses: dorny/test-reporter@v1
      if: success() || failure()
      with:
        name: Maven Tests
        path: target/surefire-reports/*.xml
        reporter: java-junit

  build:
    name: Build Application
    runs-on: ubuntu-latest
    needs: test
    if: github.event_name == 'push'

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Set up JDK 21
      uses: actions/setup-java@v4
      with:
        java-version: '21'
        distribution: 'temurin'
        cache: maven

    - name: Build application
      run: mvn clean package -DskipTests -DskipSpotless=true

    - name: Upload JAR artifact
      uses: actions/upload-artifact@v4
      with:
        name: app-jar
        path: target/*.jar
        retention-days: 1

  docker:
    name: Build and Push Docker Image
    runs-on: ubuntu-latest
    needs: build
    if: github.event_name == 'push'
    permissions:
      contents: read
      packages: write

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Download JAR artifact
      uses: actions/download-artifact@v4
      with:
        name: app-jar
        path: target/

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3
      with:
        driver-opts: |
          image=moby/buildkit:latest
          network=host

    - name: Log in to Container Registry
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ${{ env.REGISTRY }}/${{ github.repository }}
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=sha,prefix={{branch}}-
          type=raw,value=latest,enable={{is_default_branch}}
          type=raw,value=production,enable=${{ github.ref == 'refs/heads/prod' }}

    - name: Build and push Docker image
      uses: docker/build-push-action@v5
      with:
        context: .
        file: ./Dockerfile.ci
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: |
          type=registry,ref=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:buildcache
          type=gha
        cache-to: |
          type=registry,ref=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:buildcache,mode=max
          type=gha,mode=max
        platforms: linux/arm64

  deploy:
    name: Deploy to Docker Swarm
    runs-on: self-hosted
    needs: docker
    if: github.ref == 'refs/heads/prod'
    environment: production

    steps:
      - name: Deploy to Docker Swarm
        run: |
          # Login no registry
          echo ${{ secrets.GITHUB_TOKEN }} | docker login ${{ env.REGISTRY }} -u ${{ github.actor }} --password-stdin

          # Pull da nova imagem
          docker pull ${{ env.REGISTRY }}/${{ github.repository }}:latest

          # ⚠️ AJUSTAR: Nome do serviço no seu Docker Stack
          SERVICE_NAME="seu_stack_seu-service"

          if docker service inspect $SERVICE_NAME >/dev/null 2>&1; then
            echo "✅ Serviço encontrado: $SERVICE_NAME"

            CURRENT_IMAGE=$(docker service inspect $SERVICE_NAME --format='{{.Spec.TaskTemplate.ContainerSpec.Image}}')
            echo "📸 Imagem atual: $CURRENT_IMAGE"

            # Atualizar com rollback automático
            docker service update \
              --image ${{ env.REGISTRY }}/${{ github.repository }}:latest \
              --update-parallelism 1 \
              --update-delay 10s \
              --update-order start-first \
              --update-failure-action rollback \
              --update-monitor 30s \
              --update-max-failure-ratio 0.5 \
              --rollback-parallelism 1 \
              --rollback-delay 0s \
              --rollback-order stop-first \
              --rollback-monitor 10s \
              --rollback-max-failure-ratio 0 \
              --with-registry-auth \
              $SERVICE_NAME
          else
            echo "❌ Serviço $SERVICE_NAME não encontrado!"
            exit 1
          fi

          docker image prune -f --filter "until=24h"

      - name: Verify deployment
        run: |
          SERVICE_NAME="seu_stack_seu-service"
          # ⚠️ AJUSTAR: URL do health check
          HEALTH_URL="http://192.168.0.2/seu-app/actuator/health"
          MAX_ATTEMPTS=60
          SLEEP_TIME=5

          echo "=== Verificando health do serviço ==="

          for i in $(seq 1 $MAX_ATTEMPTS); do
            RUNNING=$(docker service ps "$SERVICE_NAME" --filter "desired-state=running" --format "{{.CurrentState}}" | grep -c "Running" || echo "0")
            TOTAL=$(docker service inspect "$SERVICE_NAME" --format='{{.Spec.Mode.Replicated.Replicas}}')

            # Verificar Docker health interno (importante!)
            TASK_ID=$(docker service ps "$SERVICE_NAME" --filter "desired-state=running" --format "{{.ID}}" --no-trunc | head -1)
            if [ -n "$TASK_ID" ]; then
              CONTAINER_ID=$(docker inspect "$TASK_ID" --format='{{.Status.ContainerStatus.ContainerID}}' 2>/dev/null || echo "")
              if [ -n "$CONTAINER_ID" ]; then
                DOCKER_HEALTH=$(docker inspect "$CONTAINER_ID" --format='{{.State.Health.Status}}' 2>/dev/null || echo "none")
              else
                DOCKER_HEALTH="unknown"
              fi
            else
              DOCKER_HEALTH="no-task"
            fi

            echo "[$i/$MAX_ATTEMPTS] Tasks: $RUNNING/$TOTAL | Health: $DOCKER_HEALTH"

            # Aguardar container healthy antes de testar HTTP
            if [ "$RUNNING" -ge "$TOTAL" ] && [ "$DOCKER_HEALTH" = "healthy" ]; then
              HTTP_CODE=$(curl -s -o /tmp/health.json -w "%{http_code}" "$HEALTH_URL" || echo "000")

              if [ "$HTTP_CODE" = "200" ]; then
                HEALTH_STATUS=$(python3 -c "import json; print(json.load(open('/tmp/health.json')).get('status', 'UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")

                if [ "$HEALTH_STATUS" = "UP" ]; then
                  echo "✅ Deploy verificado com sucesso!"
                  echo "   HTTP: $HTTP_CODE | Status: $HEALTH_STATUS"
                  docker service logs --tail 20 "$SERVICE_NAME"
                  exit 0
                fi
              fi
            fi

            # Detectar rollback
            UPDATE_STATE=$(docker service inspect "$SERVICE_NAME" --format='{{.UpdateStatus.State}}' 2>/dev/null || echo "unknown")
            if [ "$UPDATE_STATE" = "rollback_completed" ]; then
              echo "❌ Rollback automático executado!"
              docker service logs --tail 100 "$SERVICE_NAME"
              exit 1
            fi

            sleep $SLEEP_TIME
          done

          echo "❌ Timeout após $((MAX_ATTEMPTS * SLEEP_TIME))s"
          docker service logs --tail 100 "$SERVICE_NAME"
          exit 1
```

**📝 Variáveis para ajustar:**
- `SERVICE_NAME`: Nome do serviço no Docker Swarm
- `HEALTH_URL`: URL do endpoint /actuator/health

---

## 📄 Arquivo 2: `Dockerfile.ci`

```dockerfile
# Multi-stage otimizado para ARM64 + Java 21

# ==========================================
# Stage 1: Extração de Layers
# ==========================================
FROM eclipse-temurin:21-jre-jammy AS extractor
WORKDIR /app
COPY target/*.jar app.jar

# Extrair layers do Spring Boot
# Isso permite cache otimizado do Docker
RUN java -Djarmode=layertools -jar app.jar extract

# ==========================================
# Stage 2: Imagem Final (ARM64)
# ==========================================
FROM eclipse-temurin:21-jre-jammy AS app
WORKDIR /app

# Otimizações JVM para Produção ARM64
ENV JAVA_TOOL_OPTIONS="\
-XX:+UseContainerSupport \
-XX:MaxRAMPercentage=75.0 \
-XX:InitialRAMPercentage=50.0 \
-XX:+UseG1GC \
-XX:MaxGCPauseMillis=200 \
-XX:+UseStringDeduplication \
-XX:+TieredCompilation \
-XX:TieredStopAtLevel=1"

# Copiar layers separadamente (melhor cache)
# Ordem: menos mudança → mais mudança
COPY --from=extractor /app/dependencies/ ./
COPY --from=extractor /app/spring-boot-loader/ ./
COPY --from=extractor /app/snapshot-dependencies/ ./
COPY --from=extractor /app/application/ ./

# Usuário não-root (segurança)
RUN useradd -m appuser && \
    chown -R appuser:appuser /app

USER appuser

ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
```

**Explicação das JVM flags:**

| Flag | Propósito | Benefício ARM64 |
|------|-----------|-----------------|
| `UseContainerSupport` | Detecta limites do container | Usa RAM/CPU corretos |
| `MaxRAMPercentage=75` | Usa até 75% da RAM | Otimizado para containers |
| `UseG1GC` | Garbage Collector G1 | Ótimo em ARM64 |
| `MaxGCPauseMillis=200` | Limita pausas GC | Low-latency |
| `UseStringDeduplication` | Deduplica Strings | Economiza RAM |
| `TieredCompilation` | JIT otimizado | Startup mais rápido |
| `TieredStopAtLevel=1` | Compila apenas C1 | Startup ainda mais rápido |

---

## 📄 Arquivo 3: `pom.xml` (Trechos Relevantes)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>

    <!-- ⚠️ AJUSTAR -->
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.5</version>
        <relativePath/>
    </parent>

    <!-- ⚠️ AJUSTAR -->
    <groupId>com.sua.empresa</groupId>
    <artifactId>seu-servico</artifactId>
    <version>1.0</version>
    <name>seu-servico</name>
    <description>Seu projeto Spring Boot</description>

    <properties>
        <java.version>21</java.version>
        <maven.compiler.release>21</maven.compiler.release>
        <maven.compiler.incremental>true</maven.compiler.incremental>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>

    <dependencies>
        <!-- Spring Boot Essentials -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>

        <!-- Monitoring -->
        <dependency>
            <groupId>io.micrometer</groupId>
            <artifactId>micrometer-registry-prometheus</artifactId>
        </dependency>

        <!-- Database -->
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
        </dependency>

        <!-- Lombok (opcional) -->
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <scope>provided</scope>
        </dependency>

        <!-- Test -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>com.h2database</groupId>
            <artifactId>h2</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <!-- Spring Boot Plugin com LAYERS habilitado -->
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <configuration>
                    <!-- ⚠️ AJUSTAR: sua classe main -->
                    <mainClass>com.sua.empresa.Application</mainClass>
                    <layers>
                        <enabled>true</enabled>
                    </layers>
                    <excludes>
                        <exclude>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok</artifactId>
                        </exclude>
                    </excludes>
                </configuration>
            </plugin>

            <!-- Compiler Plugin -->
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.11.0</version>
                <configuration>
                    <release>21</release>
                    <compilerArgs>
                        <arg>-parameters</arg>
                    </compilerArgs>
                    <annotationProcessorPaths>
                        <path>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok</artifactId>
                            <version>1.18.30</version>
                        </path>
                    </annotationProcessorPaths>
                </configuration>
            </plugin>

            <!-- Surefire: Testes Paralelos -->
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-surefire-plugin</artifactId>
                <version>3.1.2</version>
                <configuration>
                    <parallel>classes</parallel>
                    <threadCount>4</threadCount>
                    <perCoreThreadCount>true</perCoreThreadCount>
                    <forkCount>2C</forkCount>
                    <reuseForks>true</reuseForks>
                    <argLine>-Xmx1024m</argLine>
                </configuration>
            </plugin>

            <!-- Spotless: Code Formatting (opcional) -->
            <plugin>
                <groupId>com.diffplug.spotless</groupId>
                <artifactId>spotless-maven-plugin</artifactId>
                <version>2.43.0</version>
                <configuration>
                    <skip>${skipSpotless}</skip>
                    <java>
                        <googleJavaFormat>
                            <version>1.17.0</version>
                            <style>AOSP</style>
                        </googleJavaFormat>
                    </java>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
```

**🔑 Pontos Críticos:**
- `<layers><enabled>true</enabled></layers>` - **ESSENCIAL** para Dockerfile.ci
- `<release>21</release>` - Java 21
- Testes paralelos - 212 testes em ~2min

---

## 📄 Arquivo 4: `application.yml`

```yaml
server:
  port: 8080
  servlet:
    context-path: /seu-app    # ⚠️ AJUSTAR

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      enabled: true
      show-details: always
  metrics:
    export:
      prometheus:
        enabled: true
    tags:
      application: ${spring.application.name}

spring:
  application:
    name: seu-servico          # ⚠️ AJUSTAR
  jpa:
    hibernate:
      ddl-auto: update
  cache:
    caffeine:
      spec: maximumSize=500,expireAfterWrite=10m
```

**Endpoints expostos:**
- `/actuator/health` - Health check (usado pelo CI/CD)
- `/actuator/info` - Informações da app
- `/actuator/metrics` - Métricas raw
- `/actuator/prometheus` - Métricas Prometheus

---

## 📄 Arquivo 5: `application-test.yml`

```yaml
spring:
  datasource:
    url: jdbc:h2:mem:testdb;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE
    driver-class-name: org.h2.Driver
    username: sa
    password:
  jpa:
    hibernate:
      ddl-auto: create-drop
    properties:
      hibernate:
        dialect: org.hibernate.dialect.H2Dialect

logging:
  level:
    root: WARN
    com.sua.empresa: DEBUG
```

**H2 in-memory:** Testes rápidos sem PostgreSQL real

---

## 📄 Arquivo 6: `docker-compose.yml` (Stack)

```yaml
version: '3.8'

services:
  seu-servico:
    image: ghcr.io/seu-usuario/seu-servico:latest
    environment:
      - SPRING_PROFILES_ACTIVE=production
      - JAVA_TOOL_OPTIONS=-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0
    env_file:
      - .env
    networks:
      - public_network
      - seu_stack_internal
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider",
             "http://localhost:8080/seu-app/actuator/health"]
      interval: 15s
      timeout: 10s
      start_period: 40s
      retries: 3
    deploy:
      mode: replicated
      replicas: 1
      resources:
        limits:
          memory: 1.5G
        reservations:
          memory: 1G
      labels:
        - traefik.enable=true
        - traefik.http.routers.seu-app.rule=Host(`api.seudominio.com`)
        - traefik.http.routers.seu-app.entrypoints=websecure
        - traefik.http.routers.seu-app.tls.certresolver=letsencrypt
        - traefik.http.services.seu-app.loadbalancer.server.port=8080
        - traefik.docker.network=public_network

networks:
  public_network:
    external: true
  seu_stack_internal:
    driver: overlay
```

---

## 🏥 Health Check

### Timing Explicado

```yaml
start_period: 40s    # Spring Boot leva ~35s para iniciar
interval: 15s        # Verificar a cada 15s após start_period
timeout: 10s         # Timeout do comando wget
retries: 3           # Tolerar 3 falhas consecutivas
```

**Timeline:**
```
0s     - Container inicia
35s    - Spring Boot ready
40s    - Primeiro health check (após start_period)
55s    - Segundo health check (interval 15s)
70s    - Marcado como healthy (após 2-3 checks OK)
```

**Por que 40s?**
- Spring Boot ARM64 leva ~33-37s
- Buffer de 3-5s para segurança
- Se < 40s, pode falhar antes de Spring estar pronto
- Se > 40s, demora desnecessariamente

---

## 🔄 Rollback Automático

### Como Funciona

```yaml
docker service update \
  --update-failure-action rollback \      # Rollback se falhar
  --update-monitor 30s \                  # Monitorar por 30s
  --update-max-failure-ratio 0.5 \        # Tolerar 50% falhas
  --rollback-order stop-first             # Parar nova, restaurar antiga
```

**Cenários de Rollback:**

1. **Container não inicia**
   ```
   → Docker detecta falha de startup
   → Rollback automático após 30s
   → Versão anterior restaurada
   ```

2. **Health check falha**
   ```
   → Container inicia mas health check retorna 500
   → Após 3 retries, Docker marca como unhealthy
   → Rollback automático
   ```

3. **Crash loop**
   ```
   → Container reinicia repetidamente
   → Docker detecta instabilidade
   → Rollback automático
   ```

**CI/CD detecta rollback:**
```bash
UPDATE_STATE=$(docker service inspect $SERVICE_NAME --format='{{.UpdateStatus.State}}')
if [ "$UPDATE_STATE" = "rollback_completed" ]; then
  echo "❌ Rollback executado!"
  exit 1
fi
```

---

## 📊 Performance Esperada

### Orange Pi 5 Plus (ARM64)

**CI/CD completo:**
```
test:    2min 15s (212 testes)
build:   1min 05s (Maven package)
docker:  2min 30s (build + push)
deploy:  1min 10s (pull + update + health)
───────────────────────────────────
Total:   ~6-7 minutos
```

**Spring Boot startup:**
```
JVM init:           ~5s
Spring context:     ~25s
Database migration: ~3s
Cache warmup:       ~2s
───────────────────────────
Total startup:      ~35s
Health ready:       ~40s
```

---

## 🔐 Secrets (NÃO são necessários!)

**❌ Remover se tiver:**
- ~~SWARM_HOST~~
- ~~SWARM_USER~~
- ~~SWARM_SSH_KEY~~
- ~~SWARM_SSH_PORT~~

**✅ Único secret usado:**
- `GITHUB_TOKEN` - Gerado automaticamente pelo GitHub

**Por quê?** Self-hosted runner tem acesso direto ao Docker local.

---

## 🎯 Checklist de Implementação

### Setup Inicial

- [ ] Self-hosted runner instalado no Orange Pi
- [ ] Runner conectado ao repositório
- [ ] Docker 24.0+ instalado
- [ ] Java 21 instalado (para tests locais opcionais)

### Configuração do Projeto

- [ ] Copiar `ci-cd-hybrid.yml` (ou `ci-cd-selfhosted.yml`)
- [ ] Copiar `Dockerfile.ci`
- [ ] Ajustar SERVICE_NAME no workflow
- [ ] Ajustar HEALTH_URL no workflow
- [ ] Ajustar mainClass no pom.xml
- [ ] Habilitar layers no pom.xml
- [ ] Configurar actuator no application.yml

### GitHub Settings

- [ ] Settings → Actions → General
- [ ] Workflow permissions → **Read and write** ✅
- [ ] (Repo privado com suporte ARM64 já incluso)

### Deploy Inicial

- [ ] Criar `.env` com secrets
- [ ] Deploy manual primeira vez: `docker stack deploy -c docker-compose.yml seu_stack`
- [ ] Verificar serviço criado: `docker service ls`

### Teste

- [ ] Push para branch prod
- [ ] Acompanhar workflow no GitHub Actions
- [ ] Verificar deploy bem-sucedido
- [ ] Testar health check: `curl http://192.168.0.2/seu-app/actuator/health`

---

## 🧪 Exemplo Completo: Criar Nova App

```bash
# 1. Criar projeto Spring Boot
curl https://start.spring.io/starter.zip \
  -d dependencies=web,data-jpa,actuator,prometheus \
  -d javaVersion=21 \
  -d bootVersion=3.2.5 \
  -d type=maven-project \
  -d packaging=jar \
  -d name=meu-servico \
  -o meu-servico.zip

unzip meu-servico.zip
cd meu-servico

# 2. Copiar template Orange Juice Box
cp -r ~/orange-juice-box/stacks/template-java21/.github .
cp ~/orange-juice-box/stacks/template-java21/Dockerfile.ci .
cp ~/orange-juice-box/stacks/template-java21/docker-compose.yml .

# 3. Ajustar pom.xml
# - Habilitar layers
# - Adicionar surefire paralelo

# 4. Ajustar workflow
vim .github/workflows/ci-cd.yml
# SERVICE_NAME="meu_stack_meu-servico"
# HEALTH_URL="http://192.168.0.2/meu-servico/actuator/health"

# 5. Git
git init
git remote add origin git@github.com:usuario/meu-servico.git
git add .
git commit -m "Initial commit"
git push -u origin main

# 6. Deploy inicial manual
docker stack deploy -c docker-compose.yml meu_stack

# 7. Próximos deploys são automáticos!
git commit -am "feat: alguma feature"
git push origin prod
# → Deploy automático em 6 minutos ✅
```

---

## 📚 Arquivos do Template

```
stacks/template-java21/
├── README.md
├── .github/
│   └── workflows/
│       ├── ci-cd-hybrid.yml        ← Padrão
│       └── ci-cd-selfhosted.yml    ← Alternativa
├── Dockerfile.ci
├── docker-compose.yml
├── pom.xml.template
└── src/
    ├── main/resources/
    │   ├── application.yml
    │   └── application-production.yml
    └── test/resources/
        └── application-test.yml
```

---

## 🎓 Best Practices Implementadas

✅ **Docker layers** - cache otimizado, rebuilds rápidos
✅ **Testes paralelos** - 212 testes em <2min
✅ **ARM64 nativo** - zero emulação
✅ **Self-hosted deploy** - sem SSH, acesso direto
✅ **Rollback automático** - falha = volta versão anterior
✅ **Health check 3 camadas** - Docker + HTTP + JSON status
✅ **Zero-downtime** - start-first strategy
✅ **JVM otimizada** - flags específicos ARM64
✅ **Segurança** - non-root user, resource limits
✅ **Monitoring** - Prometheus metrics integrado

---

## 🆚 Alternativa: ci-cd-selfhosted.yml

Igual ao híbrido, mas troca:

```yaml
# Trocar todas as ocorrências
runs-on: ubuntu-latest
→ runs-on: self-hosted
```

Feedback visual no GitHub: **IDÊNTICO!** ✨

---

**Orange Juice Box** ☕🍊 - Template Java 21 pronto para produção!
