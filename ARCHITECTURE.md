# Arquitetura — Orange Juice Box (OrangePi)

> Documento **empírico**: reflete o que está de fato deployado no swarm em 2026-07-04.
> Fonte da verdade = `docker stack deploy` dos composes em `stacks/`.

## Plataforma
- **Docker Swarm de nó único**: `orangepi` (Leader/Manager, Active). OrangePi 5 (rk3588, arm64), 15GB RAM.
- Deploy: historicamente `docker stack deploy` manual no Pi; agora via CI/CD (`.github/workflows/deploy-stacks.yml`) — o Pi é o self-hosted runner.

## Ingress (entrada de tráfego)
```
Internet ──▶ Cloudflare Tunnel (gateway_cloudflare-tunnel, 2 réplicas)
                        │
                        ▼
              NPM / nginx-proxy-manager (infrastructure_npm, imagem npm-crowdsec-modsec)
              + WAF (security_modsecurity / OWASP CRS) + CrowdSec (security_crowdsec)
                        │  rotas em stacks/infrastructure/npm-configs/*.conf
                        ▼
              serviços na rede public_network
```
Hostnames públicos: `staging-painel.verlyvidracaria.com` (front staging), `staging-api...` (back staging), `api...`/`my-app...` (prod). LAN via `*.nip.io`.

## Stacks deployados
| Stack | Serviços | Papel |
|---|---|---|
| **gateway** | cloudflare-tunnel (2) | Ingress público (túnel Cloudflare). *Obs: não aparece no `docker stack ls` — foi deployado fora do namespace de stack; reconciliar.* |
| **infrastructure** | npm, postgresql (16-alpine), redis (7) | Reverse proxy/WAF + Postgres compartilhado + Redis |
| **security** | crowdsec, modsecurity | WAF + IPS |
| **observability** | prometheus, grafana, netdata, cadvisor, node-exporter, dozzle, portainer, redash×4 (escala 0) | Monitoramento (**não-prod** no CI) |
| **verly** | verly-service `:latest` | **PROD** — API Verly → `verly_prod_db` |
| **verly-staging** | verly-service `:staging`, verly-frontend `:staging` | Staging — → `verly_db`. Limite mem 1G |
| **whatsapp-mvp** | orchestrator `:latest` (bot), evolution-api | **PROD** — bot WhatsApp → `verly_prod_db` + backend prod |

## Postgres compartilhado (infrastructure_postgresql)
Uma instância, múltiplos DBs: `verly_db` (staging), `verly_prod_db` (prod), schema `whatsapp_bot`. Secrets do swarm: `verly_staging_db_password`, `verly_prod_db_password`, `verly_bot_username/password`.

## Redes overlay
`public_network` (ingress-facing) · `infrastructure_postgresql_network` · `infrastructure_redis_network` · `observability_monitoring_net` · `security_security_internal` · `whatsapp-mvp_whatsapp_mvp_net` · `ingress` (swarm default).

## Classificação p/ deploy (CI/CD)
- **Prod (gate manual — GitHub Environment `production`)**: gateway, infrastructure, security, verly, verly-staging, whatsapp-mvp.
- **Não-prod (auto-deploy)**: observability.

## Débitos conhecidos
- Imagens de terceiros em `:latest` (auto-update pode quebrar healthcheck/comportamento — ver incidentes portainer 2.39.4 e healthcheck do orchestrator). Considerar pinar versões.
- `gateway` fora do namespace de stack (redeployar como stack nomeado).
- Healthcheck do bot (`/health` trava, baked na imagem) → corrigir em `verly-whatsapp-bot`.
