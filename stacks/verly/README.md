# Verly Service Stack

API principal do sistema Verly.

## Stack

- **App**: Verly Service (Spring Boot 3.2.5 + Java 21)
- **Database**: PostgreSQL 16 (stack separado)
- **CI/CD**: GitHub Actions (híbrido)
- **Deploy**: Automático via push para `prod`

## Tecnologias

- Java 21 (Eclipse Temurin)
- Spring Boot 3.2.5
- PostgreSQL 16
- Docker Swarm
- Traefik (reverse proxy)
- Prometheus metrics

## Deploy

### Automático (CI/CD)

```bash
# Push para prod → deploy automático
git push origin prod
```

### Manual

```bash
# Deploy via stack
docker stack deploy -c docker-compose.yml verly

# Ou update service direto
docker service update --image ghcr.io/verlao/verly-service:latest verly_verly-service
```

## Health Check

```bash
# Via Traefik
curl https://api.verlyvidracaria.com/verly-service/actuator/health

# Direto no container
curl http://192.168.0.2/verly-service/actuator/health
```

## Logs

```bash
# Logs do serviço
docker service logs -f verly_verly-service

# Ou via Dozzle
http://192.168.0.2:8888
```

## Métricas

- **Prometheus**: http://192.168.0.2:9091
- **Grafana**: http://192.168.0.2:3000
- **Endpoint**: /verly-service/actuator/prometheus

## Configuração

Ver: `.env.example` para variáveis de ambiente necessárias.

**Secrets gerenciados via SOPS** em `ansible/group_vars/production/secrets.yml`
