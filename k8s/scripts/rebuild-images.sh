#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../env.sh"

REPOS_BASE="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SERVICES=(
  "users-api"
  "catalog-api"
  "payments-api"
  "notifications-api"
)

echo "=================================================="
echo "  Rebuild de imagens - FIAP Cloud Games"
echo "  Imagens: ${DOCKER_USER}/*:${IMAGE_TAG}"
echo "=================================================="
echo ""

# 1. Remover imagens existentes
echo "[1/2] Removendo imagens locais..."
for service in "${SERVICES[@]}"; do
  image="${DOCKER_USER}/${service}:${IMAGE_TAG}"
  if docker image inspect "$image" &>/dev/null; then
    echo "  -> removendo $image"
    docker image rm -f "$image"
  else
    echo "  -> $image nao existe, pulando"
  fi
done
echo ""

# 2. Rebuild de cada serviço
echo "[2/2] Gerando imagens..."
FAILED=()

for service in "${SERVICES[@]}"; do
  repo="${REPOS_BASE}/postech-${service}"
  image="${DOCKER_USER}/${service}:${IMAGE_TAG}"

  if [[ ! -d "$repo" ]]; then
    echo "  ❌ Repo nao encontrado: $repo"
    FAILED+=("$service")
    continue
  fi

  if [[ ! -f "$repo/Dockerfile" ]]; then
    echo "  ❌ Dockerfile nao encontrado em: $repo"
    FAILED+=("$service")
    continue
  fi

  echo "  -> build $image (repo: $repo)"
  if docker build -t "$image" "$repo"; then
    echo "  ✅ $image criada"
  else
    echo "  ❌ Falha no build de $image"
    FAILED+=("$service")
  fi
  echo ""
done

# Resumo
echo "=================================================="
if [[ ${#FAILED[@]} -eq 0 ]]; then
  echo "  ✅ Todas as imagens geradas com sucesso!"
else
  echo "  ⚠️  Falha nos seguintes serviços: ${FAILED[*]}"
fi
echo "=================================================="
echo ""
echo "Proximo passo: publique as imagens em um registry acessivel pelo cluster."
for service in "${SERVICES[@]}"; do
  echo "  docker push ${DOCKER_USER}/${service}:${IMAGE_TAG}"
done
