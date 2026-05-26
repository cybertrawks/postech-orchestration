#!/bin/bash

# Configuracao compartilhada entre Kubernetes e Docker Compose.
# Fonte principal: postech-orchestration/.env

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_ENV_FILE="${ROOT_DIR}/.env"

if [ -f "${ROOT_ENV_FILE}" ]; then
	set -a
	# shellcheck disable=SC1090
	source "${ROOT_ENV_FILE}"
	set +a
else
	echo "Aviso: ${ROOT_ENV_FILE} nao encontrado. Usando valores padrao."
fi

: "${LOAD_BALANCER_IP:=127.0.0.1}"
: "${DOCKER_USER:=postech}"
: "${IMAGE_TAG:=1.0}"

export LOAD_BALANCER_IP
export DOCKER_USER
export IMAGE_TAG
export USERS_API_IMAGE="${DOCKER_USER}/users-api:${IMAGE_TAG}"
export CATALOG_API_IMAGE="${DOCKER_USER}/catalog-api:${IMAGE_TAG}"
export PAYMENTS_API_IMAGE="${DOCKER_USER}/payments-api:${IMAGE_TAG}"
export NOTIFICATIONS_API_IMAGE="${DOCKER_USER}/notifications-api:${IMAGE_TAG}"
