# Infrastructure Stack

**Layer:** 4 (Infrastructure)
**Services:** 3 (PostgreSQL, Redis, NPM)

---

## Overview

The Infrastructure stack provides shared backend services for all applications: database, caching, and reverse proxy.

---

## Services

### 1. PostgreSQL 16
**Image:** `postgres:16-alpine`
**Port:** 5432 (internal only)
**Databases:**
- `verly_db` (owner: verly_db_owner)
- `npm_db` (owner: npm_user)
- `redash` (owner: redash_user) - if enabled

**Resources:**
- CPU: 0.5-2.0 cores
- Memory: 512MB-2GB

**Health Check:**
```bash
docker exec $(docker ps -qf name=infrastructure_postgresql) \
  pg_isready -U verly_db_owner -d verly_db
```

### 2. Redis 7
**Image:** `redis:7-alpine`
**Port:** 6379 (internal only)
**Persistence:** AOF (Append-Only File)

**Resources:**
- CPU: 0.1-0.5 cores
- Memory: 64MB-256MB

**Health Check:**
```bash
docker exec $(docker ps -qf name=infrastructure_redis) redis-cli ping
```

### 3. Nginx Proxy Manager (NPM)
**Image:** `npm-crowdsec-modsec:1.0.0` (custom build)
**Ports:**
- 80: HTTP
- 443: HTTPS
- 81: Admin UI

**Database:** PostgreSQL (npm_db)

**Admin UI:** http://192.168.0.2:81

**Resources:**
- CPU: 0.25-1.0 cores
- Memory: 256MB-1GB

**Integrations:**
- CrowdSec LAPI: http://crowdsec:8080
- Custom Nginx configs
- PostgreSQL backend (not SQLite)

---

## Networks

- `postgresql_network` (encrypted with IPSec)
- `redis_network` (encrypted with IPSec)
- `public_network` (main routing network)
- `security_internal` (CrowdSec communication)

---

## Deployment

```bash
cd /home/matt/orange-juice-box/stacks/infrastructure

# Set environment variables
export POSTGRES_PASSWORD="<password>"
export CROWDSEC_BOUNCER_KEY="<key>"

# Deploy
docker stack deploy -c docker-compose.yml infrastructure
```

---

## Monitoring

### Service Status
```bash
docker service ls | grep infrastructure

# Expected:
# infrastructure_postgresql    1/1
# infrastructure_redis         1/1
# infrastructure_npm           1/1
```

### NPM Logs
```bash
# Backend logs
docker service logs infrastructure_npm --tail 50

# Nginx access logs
docker exec $(docker ps -qf name=infrastructure_npm) \
  tail -f /var/log/nginx/access.log
```

### Database Status
```bash
# PostgreSQL
docker exec $(docker ps -qf name=infrastructure_postgresql) \
  psql -U verly_db_owner -d verly_db -c "\l"

# Redis
docker exec $(docker ps -qf name=infrastructure_redis) \
  redis-cli INFO stats
```

---

## Documentation

- [NPM Guide](../../docs/npm-guide.md) - Complete NPM documentation
- [PostgreSQL Guide](../../docs/postgresql-guide.md) - Database management
- [Security Layers](../../docs/security-layers.md) - How NPM fits in security

---

**Stack:** infrastructure
**Status:** All services healthy ✅
**Last Updated:** 2025-10-31
