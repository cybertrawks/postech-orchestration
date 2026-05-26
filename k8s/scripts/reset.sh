#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
START_SCRIPT="$SCRIPT_DIR/start.sh"
STOP_PORT_FORWARD_SCRIPT="$SCRIPT_DIR/stop-port-forward.sh"

if [[ ! -f "$START_SCRIPT" ]]; then
  echo "Arquivo nao encontrado: $START_SCRIPT"
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

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "kubectl nao esta configurado ou o cluster esta inacessivel"
  exit 1
fi

echo "[1/2] Removendo recursos da aplicacao..."
bash "$STOP_PORT_FORWARD_SCRIPT" >/dev/null 2>&1 || true
kubectl delete namespace gamestore infrastructure --ignore-not-found=true --wait=true

echo "[2/2] Subindo ambiente novamente do zero..."
bash "$START_SCRIPT"
