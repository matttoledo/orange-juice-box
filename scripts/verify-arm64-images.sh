#!/bin/bash

echo "🔍 Orange Juice Box - ARM64 Compatibility Check"
echo ""

WARNINGS=0
ERRORS=0
CHECKED=0

echo "Verificando imagens dos serviços deployados..."
echo ""

# Verificar cada serviço
docker service ls --format "{{.Name}}\t{{.Image}}" | while IFS=$'\t' read -r name image; do
    ((CHECKED++))

    # Verificar se imagem suporta ARM64
    if docker manifest inspect "$image" 2>/dev/null | grep -q '"architecture":"arm64"'; then
        echo "✅ $name"
    else
        # Verificar se a imagem local é ARM64 (pode não ter manifest)
        LOCAL_ARCH=$(docker image inspect "$image" 2>/dev/null | grep -o '"Architecture":"[^"]*"' | cut -d'"' -f4 || echo "unknown")

        if [ "$LOCAL_ARCH" = "arm64" ]; then
            echo "✅ $name (ARM64 local, sem manifest)"
        else
            echo "⚠️  $name: $image"
            echo "    Arquitetura: $LOCAL_ARCH (verificar manualmente)"
            ((WARNINGS++))
        fi
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Resumo:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Imagens verificadas: $(docker service ls --format "{{.Name}}" | wc -l)"
echo "   ⚠️  Avisos: $WARNINGS"
echo ""

if [ $WARNINGS -eq 0 ]; then
    echo "🍊 Todas as imagens são compatíveis com ARM64!"
    exit 0
else
    echo "⚠️  Algumas imagens precisam verificação manual."
    echo ""
    echo "Como verificar:"
    echo "  docker manifest inspect <imagem:tag> | grep arm64"
    echo ""
    exit 0
fi
