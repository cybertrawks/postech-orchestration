#!/bin/bash

# =============================================================
#  Deploy completo no Kubernetes - FIAP Cloud Games
#  Execute a partir da pasta k8s/
# =============================================================

set -e

# Carregar configurações do ambiente
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$K8S_DIR/env.sh"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl nao encontrado no PATH"
  exit 1
fi

if ! command -v envsubst >/dev/null 2>&1; then
  echo "envsubst nao encontrado no PATH"
  exit 1
fi

echo "=================================================="
echo "  Deploy Postech - FIAP Cloud Games"
echo "  Imagens: $DOCKER_USER/*:$IMAGE_TAG"
echo "=================================================="
echo ""

# Verificar se kubectl está configurado
if ! kubectl cluster-info &>/dev/null; then
  echo "❌ kubectl não está configurado ou cluster inacessível."
  echo "   Configure o ~/.kube/config antes de continuar."
  exit 1
fi

# 1. Namespaces
echo "[1/5] Criando namespaces..."
kubectl apply -f "$K8S_DIR/namespace.yaml"
echo ""

# 2. Infraestrutura
echo "[2/5] Subindo infraestrutura (PostgreSQL, RabbitMQ)..."
kubectl apply -f "$K8S_DIR/infrastructure/postgresql.yaml"
kubectl apply -f "$K8S_DIR/infrastructure/rabbitmq.yaml"
echo ""
echo "Aguardando PostgreSQL..."
kubectl wait --for=condition=ready pod -l app=postgresql -n infrastructure --timeout=120s
echo "Aguardando RabbitMQ..."
kubectl wait --for=condition=ready pod -l app=rabbitmq -n infrastructure --timeout=180s
echo ""

# 3. Microsserviços com substituição de variáveis
echo "[3/5] Fazendo deploy dos microsserviços..."

for SERVICE in users-api catalog-api payments-api notifications-api; do
  FILE="$K8S_DIR/${SERVICE}/${SERVICE}.yaml"
  echo "  -> $SERVICE"
  DOCKER_USER=$DOCKER_USER \
  IMAGE_TAG=$IMAGE_TAG \
  envsubst < "$FILE" | kubectl apply -f -
done
echo ""

# 4. Aguardar microsserviços
echo "[4/5] Aguardando microsserviços subirem..."
for SERVICE in users-api catalog-api payments-api notifications-api; do
  kubectl wait --for=condition=ready pod -l app=$SERVICE -n gamestore --timeout=120s
done
echo ""

# 5. Status final
echo "[5/5] Status do deploy:"
echo ""
echo "--- Infraestrutura ---"
kubectl get pods -n infrastructure
echo ""
echo "--- Microsserviços ---"
kubectl get pods -n gamestore
echo ""
echo "=================================================="
echo "  ✅ Deploy concluído!"
echo "=================================================="
echo ""
echo "Observacao: para consultar pods em execucao, sempre informe o namespace."
echo "  Ex.: kubectl get pods -n infrastructure"
echo "       kubectl get pods -n gamestore"
echo ""
echo "URLs dos serviços:"
if [[ -n "${LOAD_BALANCER_IP:-}" ]]; then
  echo "  Users API:         http://$LOAD_BALANCER_IP:30081"
  echo "  Catalog API:       http://$LOAD_BALANCER_IP:30082"
  echo "  Payments API:      http://$LOAD_BALANCER_IP:30083"
  echo "  Notifications API: http://$LOAD_BALANCER_IP:30084"
else
  echo "  Defina LOAD_BALANCER_IP em k8s/env.sh para exibir URLs prontas."
  echo "  Ports: users=30081 catalog=30082 payments=30083 notifications=30084"
fi
echo ""
