# 🔀 CI/CD Comparison: Híbrido vs Full Self-hosted

## TL;DR

**Ambas opções têm FEEDBACK VISUAL IDÊNTICO no GitHub Actions!** ✨

A escolha é apenas **onde** o código executa e questões de **performance/custo**.

---

## 📊 Comparação Visual

### O que você vê no GitHub (AMBAS opções)

```
┌─────────────────────────────────────────────────────────┐
│  GitHub Actions - Workflow Run                          │
│                                                          │
│  ✅ test      (completed in 2m 15s)                     │
│  ✅ build     (completed in 1m 05s)                     │
│  ✅ docker    (completed in 2m 30s)                     │
│  ✅ deploy    (completed in 1m 10s)                     │
│                                                          │
│  [View logs] [Download artifacts] [Re-run]              │
└─────────────────────────────────────────────────────────┘
```

**Interface, logs, artifacts, status checks nos PRs: TUDO IGUAL!** 🎯

---

## 🔀 Opção A: Híbrido (Padrão)

### Configuração

```yaml
# .github/workflows/ci-cd-hybrid.yml
jobs:
  test:
    runs-on: ubuntu-latest    # ← GitHub-hosted (EUA)
  build:
    runs-on: ubuntu-latest    # ← GitHub-hosted
  docker:
    runs-on: ubuntu-latest    # ← GitHub-hosted
  deploy:
    runs-on: self-hosted      # ← Orange Pi (sua casa) 🍊
```

### Onde Executa

```
┌─────────────────────────────────────┐
│     GitHub Data Center (EUA)        │
│                                     │
│  ┌──────┐  ┌───────┐  ┌────────┐   │
│  │ test │  │ build │  │ docker │   │
│  └──────┘  └───────┘  └────────┘   │
│                                     │
│  Upload artifact ↓                  │
└─────────────────────────────────────┘
                  │
                  │ Download artifact
                  ↓
┌─────────────────────────────────────┐
│     Orange Pi (sua casa) 🍊         │
│                                     │
│         ┌────────┐                  │
│         │ deploy │                  │
│         └────────┘                  │
│           ↓                         │
│      Docker Swarm                   │
└─────────────────────────────────────┘
```

### Vantagens

✅ **Performance**: GitHub tem CPUs poderosas (8-16 cores), builds rápidos
✅ **Recursos preservados**: Orange Pi não sobrecarregado durante builds
✅ **Jobs paralelos**: Test e build rodam simultaneamente
✅ **Grátis**: 2000 minutos/mês (suficiente para 1-3 apps)
✅ **Ambiente limpo**: Cada run em container novo

### Desvantagens

❌ **Consome minutos GitHub**: ~5 min por deploy
❌ **Upload/download artifacts**: ~10-30s de overhead
❌ **Latência rede**: Download de dependências do Maven
❌ **Privacidade**: Código executa em servidores do GitHub

### Quando Usar

- ✅ Projeto com testes pesados (100+ testes)
- ✅ Quer builds mais rápidos possível
- ✅ Não se importa com limite de minutos (2000/mês)
- ✅ Até 2-3 apps ativos

---

## 🏠 Opção B: Full Self-hosted

### Configuração

```yaml
# .github/workflows/ci-cd-selfhosted.yml
jobs:
  test:
    runs-on: self-hosted      # ← Orange Pi 🍊
  build:
    runs-on: self-hosted      # ← Orange Pi
  docker:
    runs-on: self-hosted      # ← Orange Pi
  deploy:
    runs-on: self-hosted      # ← Orange Pi
```

### Onde Executa

```
┌─────────────────────────────────────┐
│     Orange Pi (sua casa) 🍊         │
│                                     │
│  ┌──────┐  ┌───────┐  ┌────────┐   │
│  │ test │  │ build │  │ docker │   │
│  └──────┘  └───────┘  └────────┘   │
│                  ↓                  │
│           ┌────────┐                │
│           │ deploy │                │
│           └────────┘                │
│                ↓                    │
│         Docker Swarm                │
└─────────────────────────────────────┘
```

### Vantagens

✅ **Privacidade total**: Código nunca sai do Orange Pi
✅ **Minutos ilimitados**: Sem limite de uso
✅ **Cache persistente**: Maven .m2 persiste entre runs (builds mais rápidos após primeiro)
✅ **Sem upload/download**: Artifacts ficam locais
✅ **Menor latência**: Tudo local
✅ **Controle total**: Você gerencia tudo

### Desvantagens

❌ **Sobrecarga do Orange Pi**: Pode ficar lento durante builds pesados
❌ **Builds sequenciais**: Jobs não rodam em paralelo (mesmo runner)
❌ **Ambiente compartilhado**: Cache pode causar conflitos
❌ **Manutenção**: Você gerencia limpeza de cache, espaço em disco

### Quando Usar

- ✅ Quer máxima privacidade
- ✅ Tem muitos projetos (economiza minutos GitHub)
- ✅ Orange Pi tem recursos sobrando
- ✅ Cache Maven local é vantajoso

---

## 📊 Comparação Detalhada

| Aspecto | Híbrido | Full Self-hosted |
|---------|---------|------------------|
| **Feedback Visual** | ✅ GitHub Actions UI completa | ✅ GitHub Actions UI completa |
| **Performance (primeiro build)** | ⚡⚡⚡ Muito rápido | ⚡⚡ Rápido |
| **Performance (builds seguintes)** | ⚡⚡⚡ Muito rápido | ⚡⚡⚡ Muito rápido (cache local) |
| **Custo (minutos GitHub)** | ~5 min/deploy | 0 min |
| **Custo (hardware)** | Baixo (só deploy) | Médio (tudo local) |
| **Privacidade** | ⚠️ Código no GitHub | ✅ 100% local |
| **Jobs paralelos** | ✅ Test + Build simultâneos | ❌ Sequencial |
| **Setup** | ✅ Simples | ✅ Simples |
| **Manutenção** | ✅ Baixa | ⚠️ Média (limpeza cache) |

---

## 💰 Cálculo de Custos (Minutos GitHub)

### Repositório Privado (2000 min/mês grátis)

**Híbrido:**
```
1 deploy = ~5 minutos
2000 min/mês ÷ 5 min = 400 deploys/mês ✅

Deploys/dia para esgotar:
400 deploys ÷ 30 dias = 13 deploys/dia

Realidade típica:
1-2 apps x 5 deploys/dia = 5-10 deploys/dia
Uso mensal: ~300 min (15% do limite) ✅
```

**Full Self-hosted:**
```
1 deploy = 0 minutos GitHub
Infinito deploys ✅
```

### Repositório Público (ILIMITADO)

**Ambas opções:** Minutos ilimitados! 🎉

---

## 🎯 Recomendações

### Usar Híbrido (Padrão) quando:

✅ Projeto novo começando
✅ Até 2-3 apps ativos
✅ Quer builds mais rápidos
✅ Não se importa com privacidade total
✅ 2000 min/mês é suficiente

**Exemplo:** Verly Service atual usa híbrido perfeitamente.

### Usar Full Self-hosted quando:

✅ Privacidade é crítica
✅ Muitos projetos (5+ apps)
✅ Orange Pi tem recursos sobrando
✅ Quer economizar minutos GitHub
✅ Cache local é importante

**Exemplo:** Empresa com 10+ microservices.

---

## 🔄 Migração Entre Opções

### Híbrido → Full Self-hosted

```bash
# 1. Copiar workflow
cp .github/workflows/ci-cd-hybrid.yml .github/workflows/ci-cd.yml

# 2. Trocar runs-on
sed -i 's/runs-on: ubuntu-latest/runs-on: self-hosted/g' .github/workflows/ci-cd.yml

# 3. Commit e push
git add .github/workflows/ci-cd.yml
git commit -m "ci: migrar para full self-hosted"
git push
```

**Feedback visual no GitHub: IDÊNTICO!** ✨

### Full Self-hosted → Híbrido

```bash
# 1. Copiar template híbrido
cp stacks/template-java21/.github/workflows/ci-cd-hybrid.yml .github/workflows/ci-cd.yml

# 2. Ajustar variáveis (SERVICE_NAME, HEALTH_URL)

# 3. Commit e push
```

**Troca em ~5 minutos, zero impacto visual!**

---

## 🧪 Performance Real (Orange Pi 5 Plus)

### Verly Service (212 testes, Spring Boot 3.2.5)

**Híbrido (atual):**
```
✅ test     2m 15s (ubuntu-latest)
✅ build    1m 05s (ubuntu-latest)
✅ docker   2m 30s (ubuntu-latest)
✅ deploy   1m 10s (self-hosted)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total:      6m 60s
```

**Full Self-hosted (estimado):**
```
✅ test     2m 30s (self-hosted)
✅ build    1m 15s (self-hosted)
✅ docker   3m 00s (self-hosted)
✅ deploy   1m 10s (self-hosted)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total:      7m 55s
```

**Diferença:** ~1 minuto (margem aceitável)

---

## ✅ Decisão Final

### Para Orange Juice Box:

**Padrão:** Híbrido
**Documentado:** Ambas opções
**Facilidade:** Troca em 5 minutos se mudar de ideia

### Template inclui:

```
stacks/template-java21/.github/workflows/
├── ci-cd-hybrid.yml         ← Usar por padrão
└── ci-cd-selfhosted.yml     ← Alternativa disponível
```

Escolha qual usar ao copiar para novo projeto!

---

## 🎓 Conclusão

**Não há "melhor" opção absoluta** - depende do seu contexto:

- **Poucos apps, quer velocidade?** → Híbrido ✅
- **Muitos apps, quer privacidade?** → Full Self-hosted ✅

**Ambas funcionam perfeitamente com feedback visual completo!** 🎉

---

**Orange Juice Box** 🍊 - Flexibilidade com documentação!
