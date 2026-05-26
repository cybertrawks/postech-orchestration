#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$K8S_DIR/env.sh"
DEPLOY_SCRIPT="$SCRIPT_DIR/deploy.sh"
STOP_PORT_FORWARD_SCRIPT="$SCRIPT_DIR/stop-port-forward.sh"
RUNTIME_DIR="$K8S_DIR/.runtime"
PORT_FORWARD_PID_FILE="$RUNTIME_DIR/port-forward.pids"
PORT_FORWARD_LOG_DIR="$RUNTIME_DIR/port-forward-logs"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Arquivo nao encontrado: $ENV_FILE"
  exit 1
fi

if [[ ! -f "$DEPLOY_SCRIPT" ]]; then
  echo "Arquivo nao encontrado: $DEPLOY_SCRIPT"
  exit 1
fi

if [[ ! -f "$STOP_PORT_FORWARD_SCRIPT" ]]; then
  echo "Arquivo nao encontrado: $STOP_PORT_FORWARD_SCRIPT"
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl nao encontrado no PATH"
  exit 1
fi

source "$ENV_FILE"

if [[ -z "${DOCKER_USER:-}" || -z "${IMAGE_TAG:-}" ]]; then
  echo "DOCKER_USER e IMAGE_TAG devem estar definidos em k8s/env.sh"
  exit 1
fi

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "kubectl nao esta configurado ou o cluster esta inacessivel"
  exit 1
fi

echo "[1/2] Cluster Kubernetes detectado via kubectl."
echo "        As imagens ${DOCKER_USER}/*:${IMAGE_TAG} precisam estar acessiveis pelo cluster."

echo "[2/2] Executando deploy Kubernetes..."
DOCKER_USER="$DOCKER_USER" \
IMAGE_TAG="$IMAGE_TAG" \
bash "$DEPLOY_SCRIPT"

mkdir -p "$RUNTIME_DIR" "$PORT_FORWARD_LOG_DIR"

bash "$STOP_PORT_FORWARD_SCRIPT" >/dev/null 2>&1 || true

echo "Iniciando port-forward local das APIs..."
: > "$PORT_FORWARD_PID_FILE"

start_port_forward() {
  local service="$1"
  local local_port="$2"
  local target_port="$3"
  local log_file="$PORT_FORWARD_LOG_DIR/${service}.log"

  kubectl port-forward -n gamestore "svc/${service}" "${local_port}:${target_port}" \
    > "$log_file" 2>&1 &
  local pid=$!
  echo "${pid}:${service}:${local_port}" >> "$PORT_FORWARD_PID_FILE"
}

start_postgres_port_forward() {
  local log_file="$PORT_FORWARD_LOG_DIR/postgresql.log"
  kubectl port-forward -n infrastructure svc/postgresql 5432:5432 > "$log_file" 2>&1 &
  local pid=$!
  echo "${pid}:postgresql:5432" >> "$PORT_FORWARD_PID_FILE"
}

start_postgres_port_forward

start_port_forward users-api 8081 80
start_port_forward catalog-api 8082 80
start_port_forward payments-api 8083 80
start_port_forward notifications-api 8084 80

echo "Deploy finalizado."
echo ""
echo "Acesso local via port-forward:"
echo "  Users API:         http://127.0.0.1:8081"
echo "  Catalog API:       http://127.0.0.1:8082"
echo "  Payments API:      http://127.0.0.1:8083"
echo "  Notifications API: http://127.0.0.1:8084"
echo "  PostgreSQL:        localhost:5432 (user: postech_admin, password: <ver Sealed Secret>)"
echo ""
echo "Para encerrar os port-forwards:"
echo "  bash $STOP_PORT_FORWARD_SCRIPT"
