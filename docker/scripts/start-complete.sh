#!/usr/bin/env bash

# Sobe a stack completa do compose da pasta temp com variaveis de ambiente carregadas.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${TEMP_DIR}/.." && pwd)"
COMPOSE_FILE="${TEMP_DIR}/docker-compose.yml"
ENV_FILE="${ROOT_DIR}/.env"
ENV_EXAMPLE_FILE="${ROOT_DIR}/.env.example"

if [ ! -f "${COMPOSE_FILE}" ]; then
  echo "Arquivo docker-compose.yml nao encontrado em ${TEMP_DIR}."
  exit 1
fi

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose)
else
  echo "Docker Compose nao encontrado. Instale docker compose ou docker-compose."
  exit 1
fi

if [ ! -f "${ENV_FILE}" ]; then
  if [ -f "${ENV_EXAMPLE_FILE}" ]; then
    cp "${ENV_EXAMPLE_FILE}" "${ENV_FILE}"
    echo "Arquivo .env criado a partir de .env.example em ${ROOT_DIR}."
  else
    cat >"${ENV_FILE}" <<'EOF'
# Variaveis usadas para substituicao no docker-compose.yml
DOCKER_USER=seu_usuario
IMAGE_TAG=local
BREVO_API_KEY=CHANGE_TO_YOUR_BREVO_API_KEY
EOF
    echo "Arquivo .env criado com valores padrao em ${ROOT_DIR}."
  fi
fi

set -a
source "${ENV_FILE}"
set +a

echo "Iniciando stack completa em ${TEMP_DIR}..."
(
  cd "${TEMP_DIR}"
  "${COMPOSE_CMD[@]}" --env-file "${ENV_FILE}" up -d "$@"
)

echo
"${COMPOSE_CMD[@]}" -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" ps
