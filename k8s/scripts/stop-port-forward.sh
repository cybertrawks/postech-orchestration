#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PID_FILE="$K8S_DIR/.runtime/port-forward.pids"

if [[ ! -f "$PID_FILE" ]]; then
  exit 0
fi

while IFS=: read -r pid service local_port; do
  if [[ -n "${pid:-}" ]] && kill -0 "$pid" >/dev/null 2>&1; then
    echo "Encerrando port-forward de $service na porta $local_port (PID $pid)..."
    kill "$pid" >/dev/null 2>&1 || true
  fi
done < "$PID_FILE"

rm -f "$PID_FILE"