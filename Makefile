.PHONY: help install-deps setup deploy-all deploy backup restore health-check verify-arm64 clean

STACK ?= all

help:
	@echo "🍊 Orange Juice Box - Comandos Disponíveis"
	@echo ""
	@echo "Setup:"
	@echo "  make install-deps       Instala Ansible, SOPS, age"
	@echo "  make setup              Setup inicial (Swarm + configs)"
	@echo ""
	@echo "Deploy:"
	@echo "  make deploy-all         Deploy todos os stacks"
	@echo "  make deploy STACK=X     Deploy stack específico"
	@echo ""
	@echo "Manutenção:"
	@echo "  make backup             Backup de volumes"
	@echo "  make restore DIR=X      Restore de backup"
	@echo "  make health-check       Verifica saúde dos serviços"
	@echo "  make verify-arm64       Verifica compatibilidade ARM64"
	@echo ""
	@echo "Utils:"
	@echo "  make clean              Limpa containers/images não usados"
	@echo "  make logs STACK=X       Ver logs de um stack"
	@echo ""
	@echo "Exemplos:"
	@echo "  make deploy STACK=verly"
	@echo "  make restore DIR=/home/matt/backups/orange-juice-box/2025-10-19_030000"
	@echo "  make logs STACK=verly"

install-deps:
	@echo "📦 Instalando dependências..."
	@./scripts/install-deps.sh

setup:
	@echo "🔧 Setup Orange Juice Box..."
	@cd ansible && ansible-playbook -i inventory/production.yml playbooks/site.yml

deploy-all:
	@echo "🚀 Deploy completo do Orange Juice Box..."
	@cd ansible && ansible-playbook -i inventory/production.yml playbooks/deploy-stacks.yml

deploy:
	@if [ "$(STACK)" = "all" ]; then \
		make deploy-all; \
	else \
		echo "🚀 Deploy de $(STACK)..."; \
		cd stacks/$(STACK) && docker stack deploy -c docker-compose.yml $(STACK); \
	fi

backup:
	@echo "💾 Executando backup..."
	@./scripts/backup-volumes.sh

restore:
	@if [ -z "$(DIR)" ]; then \
		echo "❌ Especifique o diretório de backup:"; \
		echo "   make restore DIR=/path/to/backup"; \
		exit 1; \
	fi
	@echo "🔄 Executando restore de $(DIR)..."
	@./scripts/restore-volumes.sh $(DIR)

health-check:
	@echo "🏥 Health check..."
	@./scripts/health-check.sh

verify-arm64:
	@echo "🔍 Verificando ARM64..."
	@./scripts/verify-arm64-images.sh

logs:
	@if [ "$(STACK)" = "all" ]; then \
		echo "❌ Especifique um stack: make logs STACK=verly"; \
		exit 1; \
	fi
	@echo "📄 Logs de $(STACK)_*..."
	@docker service logs -f $(STACK)_$(STACK) || docker service logs -f $(STACK)

clean:
	@echo "🧹 Limpando recursos não usados..."
	@docker system prune -af --volumes --filter "until=24h"
	@echo "✅ Limpeza concluída"

.DEFAULT_GOAL := help
