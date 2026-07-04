# whatsapp-mvp — WhatsApp listener da vidraçaria

Fase 1 do bot WhatsApp. Recebe mensagens via Evolution API, classifica intent via NPU (rkllm-server systemd no host),
extrai dimensões, calcula preço via `verly-service`, persiste em `verly_db.whatsapp_bot.*`.

**Read-only**: bot apenas escuta, NÃO envia mensagens nem marca como lido. Pai continua usando WhatsApp Web normal.

## Componentes

- `evolution-api` — driver WhatsApp Multi-Device. Pareado uma vez como mais um aparelho linkado ao número do pai.
- `orchestrator` — Python FastAPI. Recebe webhook do Evolution, chama rkllm-server, calcula preço, persiste.
- `rkllm-server` (systemd no host, **fora** desse stack) — Qwen2.5-1.5B NPU em `0.0.0.0:18080`.

## Pré-requisitos

1. **rkllm-server rodando** no host:
   ```
   systemctl status rkllm-server   # active (running)
   curl http://localhost:18080/health
   ```

2. **Schema `whatsapp_bot` criado** em `verly_db`:
   ```
   docker exec $(docker ps -q -f name=infrastructure_postgresql) \
     psql -U verly_db_owner -d verly_db -c "\dt whatsapp_bot.*"
   ```

3. **Database `evolution_db` criada** (separada do verly):
   ```
   docker exec $(docker ps -q -f name=infrastructure_postgresql) \
     psql -U verly_db_owner -d postgres -c "\l" | grep evolution_db
   ```

4. **Docker secrets**:
   ```
   docker secret ls
   # Esperado: whatsapp_evolution_api_key, verly_staging_db_password,
   #          verly_bot_username, verly_bot_password
   ```

5. **Build da imagem do orchestrator** (Swarm não builda; pre-build aqui):
   ```
   cd ~/orange-juice-box/stacks/whatsapp-mvp/orchestrator
   docker build -t whatsapp-mvp-orchestrator:latest .
   ```

## Deploy

```bash
cd ~/orange-juice-box/stacks/whatsapp-mvp
docker stack deploy -c docker-compose.yml whatsapp-mvp
watch -n 2 'docker service ls --filter name=whatsapp-mvp'
```

Aguardar 2/2 serviços com 1/1 replicas. Logs:

```bash
docker service logs whatsapp-mvp_evolution-api -f
docker service logs whatsapp-mvp_orchestrator -f
```

## Pareamento (uma vez na vida)

1. Configurar NPM proxy host (admin em http://192.168.15.2:81):
   - Domain: `wa-setup.orangepi.local`
   - Forward: `evolution-api:8080`
   - HTTP, sem SSL

2. Adicionar `192.168.15.2 wa-setup.orangepi.local` no `/etc/hosts` da máquina onde vai escanear (Mac do Matheus).

3. Criar instância:
   ```bash
   API_KEY=$(sudo cat /root/.whatsapp-evolution-api-key)
   curl -X POST http://wa-setup.orangepi.local/instance/create \
     -H "apikey: $API_KEY" -H "Content-Type: application/json" \
     -d '{"instanceName":"father","integration":"WHATSAPP-BAILEYS","qrcode":true}'
   ```

4. Obter QR:
   ```bash
   curl -s http://wa-setup.orangepi.local/instance/connect/father \
     -H "apikey: $API_KEY" | python3 -m json.tool
   ```
   Renderizar o `base64` retornado ou usar `/manager` UI.

5. Pai abre WhatsApp no celular → Configurações → **Aparelhos conectados** → Conectar um aparelho → escanear.

6. Confirmar:
   ```bash
   curl -s http://wa-setup.orangepi.local/instance/connectionState/father \
     -H "apikey: $API_KEY"  # esperado: {"state":"open"}
   ```

## Smoke test

De outro celular, mandar pro número do pai: `vidro temperado 1,20x0,80`.

Em ~5s:

```bash
docker exec $(docker ps -q -f name=infrastructure_postgresql) psql -U verly_db_owner -d verly_db -c "
SELECT rm.received_at, rm.remote_jid, rm.body,
       c.intent, c.llm_latency_ms,
       e.product_type, e.width_cm, e.height_cm, e.verly_status, e.price
  FROM whatsapp_bot.raw_messages rm
  LEFT JOIN whatsapp_bot.classifications c ON c.raw_message_id = rm.id
  LEFT JOIN whatsapp_bot.extractions e     ON e.raw_message_id = rm.id
  ORDER BY rm.id DESC LIMIT 5;
"
```

Esperado:
- `intent='quote_request'`
- `product_type='FIXO'`, `width_cm=120`, `height_cm=80`
- `verly_status='ok'` com `price` populado

## Riscos / observações

- **Read-only**: orchestrator NUNCA chama Evolution `/sendMessage`. Garantido pelo design (não tem código pra isso).
- **Pareamento expira em 14 dias offline**. Se o stack ficar derrubado mais que isso, reescanear QR.
- **Limite de 4 devices linkados** na conta WhatsApp do pai. Verificar antes em Aparelhos conectados.
- **WhatsApp Web do pai NÃO é afetado**: o bot é um device paralelo. Pai continua usando Chrome normalmente.
- **Não temos auto-reply**. Cliente manda, bot captura, fim.

## Fases futuras (não-MVP)

- Fase 2: migrar orchestrator pra módulo `crm` dentro do monolito `verly-service`. Manter rkllm-server systemd.
- Fase 3: Telegram bot pra entregar drafts pro pai (Aprovar/Editar/Rejeitar). Quote completo no Verly. Auto-reply pro cliente via Evolution.
- Fase 4: chip dedicado pra outbound (separação de risco).
