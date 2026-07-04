# 🔧 Comandos Úteis - Cloudflare Tunnel (Docker Swarm)

## 📊 Monitoramento

### Ver status do serviço
```bash
docker service ls | grep cloudflare
```

### Ver todas as réplicas (tasks)
```bash
docker service ps gateway_cloudflare-tunnel
```

### Ver réplicas com detalhes completos
```bash
docker service ps gateway_cloudflare-tunnel --no-trunc
```

### Logs de todas as réplicas (real-time)
```bash
docker service logs -f gateway_cloudflare-tunnel
```

### Logs das últimas 100 linhas
```bash
docker service logs --tail 100 gateway_cloudflare-tunnel
```

### Logs de uma réplica específica
```bash
# Listar containers
docker ps | grep cloudflare

# Ver logs
docker logs -f <container_id>
```

---

## 🏥 Health Check

### Verificar health de todas as réplicas
```bash
docker service ps gateway_cloudflare-tunnel --format 'table {{.Name}}\t{{.CurrentState}}'
```

### Inspecionar health check config
```bash
docker service inspect gateway_cloudflare-tunnel --format '{{json .Spec.TaskTemplate.ContainerSpec.Healthcheck}}' | jq
```

### Executar health check manualmente
```bash
# Pegar ID do container
CONTAINER_ID=$(docker ps -q -f name=cloudflare-tunnel | head -1)

# Executar ready check
docker exec $CONTAINER_ID cloudflared tunnel --metrics 0.0.0.0:2000 ready
```

---

## 📈 Métricas

### Ver métricas de uma réplica
```bash
# Pegar ID do container
CONTAINER_ID=$(docker ps -q -f name=cloudflare-tunnel | head -1)

# Métricas Prometheus
docker exec $CONTAINER_ID wget -qO- http://localhost:2000/metrics
```

### Métricas importantes
```bash
# Conexões ativas
docker exec $CONTAINER_ID wget -qO- http://localhost:2000/metrics | grep cloudflared_tunnel_ha_connections

# Total de requests
docker exec $CONTAINER_ID wget -qO- http://localhost:2000/metrics | grep cloudflared_tunnel_total_requests

# Erros
docker exec $CONTAINER_ID wget -qO- http://localhost:2000/metrics | grep cloudflared_tunnel_request_errors
```

### Testar endpoint público
```bash
# Health check da API
curl -I https://api.verlyvidracaria.com/verly-service/actuator/health

# Com detalhes
curl -sS https://api.verlyvidracaria.com/verly-service/actuator/health | jq
```

---

## 🔄 Gerenciamento

### Escalar réplicas
```bash
# Aumentar para 5 réplicas
docker service scale gateway_cloudflare-tunnel=5

# Reduzir para 2 réplicas
docker service scale gateway_cloudflare-tunnel=2
```

### Forçar restart de uma réplica específica
```bash
# Listar tasks
docker service ps gateway_cloudflare-tunnel

# Forçar restart (remover task específica)
docker service update --force gateway_cloudflare-tunnel
```

### Update do serviço (sem downtime)
```bash
cd /home/matt/orange-juice-box/stacks/gateway
docker stack deploy -c docker-compose.yml gateway
```

### Rollback para versão anterior
```bash
docker service rollback gateway_cloudflare-tunnel
```

---

## 🔍 Troubleshooting

### Ver histórico de falhas
```bash
docker service ps gateway_cloudflare-tunnel --filter "desired-state=shutdown"
```

### Inspecionar task que falhou
```bash
# Pegar ID da task com erro
docker service ps gateway_cloudflare-tunnel --no-trunc | grep Failed

# Ver detalhes
docker inspect <task_id>
```

### Ver eventos do Swarm
```bash
docker events --filter service=gateway_cloudflare-tunnel
```

### Verificar recursos consumidos
```bash
# CPU e memória de cada réplica
docker stats --no-stream $(docker ps -q -f name=cloudflare-tunnel)
```

### Testar conectividade de dentro do container
```bash
CONTAINER_ID=$(docker ps -q -f name=cloudflare-tunnel | head -1)

# Testar DNS
docker exec $CONTAINER_ID nslookup api.cloudflare.com

# Testar rede interna
docker exec $CONTAINER_ID wget -qO- http://security_modsecurity:8080
```

---

## ⚙️ Configuração

### Ver configuração completa do serviço
```bash
docker service inspect gateway_cloudflare-tunnel --pretty
```

### Ver somente restart policy
```bash
docker service inspect gateway_cloudflare-tunnel --format '{{json .Spec.TaskTemplate.RestartPolicy}}' | jq
```

### Ver somente health check
```bash
docker service inspect gateway_cloudflare-tunnel --format '{{json .Spec.TaskTemplate.ContainerSpec.Healthcheck}}' | jq
```

### Ver réplicas configuradas
```bash
docker service inspect gateway_cloudflare-tunnel --format '{{.Spec.Mode.Replicated.Replicas}}'
```

### Ver recursos (CPU/Mem)
```bash
docker service inspect gateway_cloudflare-tunnel --format '{{json .Spec.TaskTemplate.Resources}}' | jq
```

---

## 🔐 Segurança

### Ver token configurado (mascarado)
```bash
docker service inspect gateway_cloudflare-tunnel --format '{{range .Spec.TaskTemplate.ContainerSpec.Args}}{{println .}}{{end}}' | grep token
```

### Rotacionar token
```bash
# 1. Gerar novo token no Cloudflare Dashboard
# 2. Atualizar variável de ambiente
export TUNNEL_TOKEN="novo_token_aqui"

# 3. Re-deploy
cd /home/matt/orange-juice-box/stacks/gateway
docker stack deploy -c docker-compose.yml gateway
```

---

## 📦 Backup e Restore

### Backup da configuração
```bash
cd /home/matt/orange-juice-box/stacks/gateway
cp docker-compose.yml docker-compose.yml.backup-$(date +%Y%m%d-%H%M%S)
```

### Restore de backup
```bash
cd /home/matt/orange-juice-box/stacks/gateway
cp docker-compose.yml.backup-YYYYMMDD-HHMMSS docker-compose.yml
docker stack deploy -c docker-compose.yml gateway
```

---

## 🚨 Alertas e Notificações

### Criar alerta para quando réplica cair
```bash
# Script de monitoramento (executar via cron)
cat > /home/matt/check-tunnel.sh <<'EOF'
#!/bin/bash
EXPECTED=3
ACTUAL=$(docker service ls --filter name=gateway_cloudflare --format "{{.Replicas}}" | cut -d/ -f1)

if [ "$ACTUAL" -lt "$EXPECTED" ]; then
    echo "⚠️ ALERTA: Cloudflare Tunnel com apenas $ACTUAL/$EXPECTED réplicas!" | \
    mail -s "Alert: Tunnel Down" seu-email@example.com
fi
EOF

chmod +x /home/matt/check-tunnel.sh

# Adicionar ao crontab (verificar a cada minuto)
# crontab -e
# * * * * * /home/matt/check-tunnel.sh
```

---

## 🧪 Testes

### Simular falha (derrubar uma réplica)
```bash
# Pegar um container
CONTAINER_ID=$(docker ps -q -f name=cloudflare-tunnel | head -1)

# Parar container
docker stop $CONTAINER_ID

# Observar Swarm reiniciando automaticamente
watch docker service ps gateway_cloudflare-tunnel
```

### Teste de carga
```bash
# Gerar tráfego
for i in {1..100}; do
  curl -sS -o /dev/null -w "%{http_code}\n" https://api.verlyvidracaria.com/verly-service/actuator/health &
done

# Monitorar réplicas
docker stats $(docker ps -q -f name=cloudflare-tunnel)
```

---

## 📊 Dashboards

### Dashboard simples no terminal (watch)
```bash
watch -n 2 'docker service ls | grep cloudflare; echo ""; docker service ps gateway_cloudflare-tunnel | head -10'
```

### Ver todas as conexões ativas
```bash
for container in $(docker ps -q -f name=cloudflare-tunnel); do
  echo "=== Container: $container ==="
  docker exec $container wget -qO- http://localhost:2000/metrics 2>/dev/null | grep cloudflared_tunnel_ha_connections
  echo ""
done
```

---

## 🔄 Automação

### Auto-restart se réplica ficar abaixo de 3
```bash
# Script: /home/matt/auto-heal-tunnel.sh
#!/bin/bash
MIN_REPLICAS=3

while true; do
  CURRENT=$(docker service ls --filter name=gateway_cloudflare --format "{{.Replicas}}" | cut -d/ -f1)
  
  if [ "$CURRENT" -lt "$MIN_REPLICAS" ]; then
    echo "[$(date)] ⚠️  Apenas $CURRENT réplicas, forçando update..."
    docker service update --force gateway_cloudflare-tunnel
  fi
  
  sleep 60
done

# Executar em background
# nohup /home/matt/auto-heal-tunnel.sh > /var/log/tunnel-heal.log 2>&1 &
```

---

## 📚 Referências Rápidas

### Documentação completa
```bash
cat /home/matt/CLOUDFLARE_TUNNEL_RESILIENCE_STRATEGY.md | less
```

### Aplicar melhorias HA
```bash
cd /home/matt/orange-juice-box/stacks/gateway
chmod +x apply-ha-improvements.sh
./apply-ha-improvements.sh
```

### Dozzle (Web UI para logs)
```
http://orangepi:8080
```

### Portainer (Web UI para Docker)
```
http://orangepi:9000
```

### Prometheus
```
http://orangepi:9090
```

### Grafana
```
http://orangepi:3000
```

---

## 🆘 Comandos de Emergência

### Reiniciar tudo (último recurso)
```bash
# Remover serviço
docker service rm gateway_cloudflare-tunnel

# Re-deploy
cd /home/matt/orange-juice-box/stacks/gateway
docker stack deploy -c docker-compose.yml gateway
```

### Verificar se Docker está OK
```bash
docker info
docker node ls
docker service ls
```

### Logs do Docker daemon
```bash
sudo journalctl -u docker -f
```

---

**Última atualização**: 18/12/2025  
**Maintainer**: Orange Pi / Docker Swarm  
**Stack**: gateway (Cloudflare Tunnel)

