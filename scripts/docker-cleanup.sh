#!/bin/bash
# Docker Cleanup Script
# Executa limpeza automática de recursos não utilizados do Docker

LOG_FILE="/var/log/docker-cleanup.log"

echo "=== Docker Cleanup - $(date) ===" | tee -a "$LOG_FILE"

# 1. Remover containers parados
echo "Removing stopped containers..." | tee -a "$LOG_FILE"
docker container prune -f 2>&1 | tee -a "$LOG_FILE"

# 2. Remover imagens não usadas (não incluindo as em uso)
echo "Removing unused images..." | tee -a "$LOG_FILE"
docker image prune -a -f --filter "until=720h" 2>&1 | tee -a "$LOG_FILE"

# 3. Remover volumes órfãos (cuidado!)
# Comentado por segurança - descomentar se quiser limpar volumes não usados
# echo "Removing orphaned volumes..." | tee -a "$LOG_FILE"
# docker volume prune -f 2>&1 | tee -a "$LOG_FILE"

# 4. Remover redes não usadas
echo "Removing unused networks..." | tee -a "$LOG_FILE"
docker network prune -f 2>&1 | tee -a "$LOG_FILE"

# 5. Remover build cache (se usando buildkit)
echo "Removing build cache..." | tee -a "$LOG_FILE"
docker builder prune -f --filter "until=168h" 2>&1 | tee -a "$LOG_FILE"

echo "=== Cleanup completed - $(date) ===" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
