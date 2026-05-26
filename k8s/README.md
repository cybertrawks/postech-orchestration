# postech-orchestration - Kubernetes

Manifests e scripts para deploy do FIAP Cloud Games em Kubernetes.

## Dependências

- `kubectl` instalado e configurado para um cluster acessível (`kubectl cluster-info` deve funcionar)
- `envsubst` instalado (pacote `gettext`)
- Docker (necessário para rebuild/push das imagens usadas pelo cluster)
- Bash

## Visão geral do que é deployado

- Namespaces: `gamestore` e `infrastructure`
- Infraestrutura padrão do script `deploy.sh`:
    - PostgreSQL
    - RabbitMQ
- Microsserviços:
    - users-api
    - catalog-api
    - payments-api
    - notifications-api

Observação: existe manifesto para Redis em `infrastructure/redis.yaml`, mas o `scripts/deploy.sh` atual nao aplica esse recurso automaticamente.

## Configuração do ambiente

Edite `postech-orchestration/.env` antes do primeiro deploy:

```bash
export LOAD_BALANCER_IP="192.168.49.2"  # IP/host para acesso via NodePort
export DOCKER_USER="seu_usuario"        # dono das imagens no registry
export IMAGE_TAG="1.0"                  # tag das imagens
```

O arquivo `k8s/env.sh` apenas carrega essas variaveis da raiz para manter
consistencia com o Docker Compose em `temp/`.

As imagens esperadas no cluster seguem o padrão:

```text
${DOCKER_USER}/users-api:${IMAGE_TAG}
${DOCKER_USER}/catalog-api:${IMAGE_TAG}
${DOCKER_USER}/payments-api:${IMAGE_TAG}
${DOCKER_USER}/notifications-api:${IMAGE_TAG}
```

## Scripts disponíveis e funcionalidades

Todos os comandos abaixo partem da pasta `k8s/scripts`.

### `start.sh`
- Valida `kubectl`, `env.sh` e acesso ao cluster.
- Executa `deploy.sh`.
- Inicia `kubectl port-forward` para as APIs e PostgreSQL.
- Armazena PIDs em `k8s/.runtime/port-forward.pids`.

```bash
cd k8s/scripts
bash start.sh
```

Portas locais abertas por `start.sh`:

- `http://127.0.0.1:8081` -> users-api
- `http://127.0.0.1:8082` -> catalog-api
- `http://127.0.0.1:8083` -> payments-api
- `http://127.0.0.1:8084` -> notifications-api
- `localhost:5432` -> postgresql (namespace `infrastructure`)

### `deploy.sh`
- Aplica namespaces.
- Aplica PostgreSQL e RabbitMQ.
- Aguarda pods ficarem prontos.
- Faz `envsubst` nos manifests das APIs para substituir `${DOCKER_USER}` e `${IMAGE_TAG}`.

```bash
cd k8s/scripts
bash deploy.sh
```

### `stop-port-forward.sh`
- Encerra os processos de `kubectl port-forward` iniciados por `start.sh`.

```bash
cd k8s/scripts
bash stop-port-forward.sh
```

### `reset.sh`
- Remove os namespaces `gamestore` e `infrastructure`.
- Executa `start.sh` em seguida para recriar tudo do zero.

```bash
cd k8s/scripts
bash reset.sh
```

### `rebuild-images.sh`
- Remove imagens locais `${DOCKER_USER}/*:${IMAGE_TAG}`.
- Rebuilda imagens dos repositórios irmãos em `${HOME}/code/studies/fiap/fase_2/postech-<service>`.
- Exibe comandos `docker push` ao final.

```bash
cd k8s/scripts
bash rebuild-images.sh
```

## Exemplo completo (Docker + Kubernetes + kubectl)

### 1) Rebuild das imagens locais

```bash
cd k8s/scripts
bash rebuild-images.sh
```

### 2) Publicar imagens no registry

```bash
docker push ${DOCKER_USER}/users-api:${IMAGE_TAG}
docker push ${DOCKER_USER}/catalog-api:${IMAGE_TAG}
docker push ${DOCKER_USER}/payments-api:${IMAGE_TAG}
docker push ${DOCKER_USER}/notifications-api:${IMAGE_TAG}
```

### 3) Deploy no cluster

```bash
cd k8s/scripts
bash start.sh
```

### 4) Validar recursos com kubectl

Importante: para consultar os pods em execucao neste projeto, informe sempre o namespace com `-n`, pois os recursos ficam separados entre `gamestore` e `infrastructure`.

```bash
kubectl get ns
kubectl get pods -n infrastructure
kubectl get pods -n gamestore
kubectl get svc -n gamestore
```

### 5) Ver logs de uma API

```bash
kubectl logs -n gamestore deploy/users-api -f
```

### 6) Testar APIs

Opcao A (via port-forward do `start.sh`):

```bash
curl http://127.0.0.1:8081
curl http://127.0.0.1:8082
```

Opcao B (via NodePort):

```bash
curl http://${LOAD_BALANCER_IP}:30081
curl http://${LOAD_BALANCER_IP}:30082
curl http://${LOAD_BALANCER_IP}:30083
curl http://${LOAD_BALANCER_IP}:30084
```

## Comandos kubectl úteis

```bash
kubectl describe pod -n gamestore <pod-name>
kubectl rollout status deployment/users-api -n gamestore
kubectl get events -n gamestore --sort-by=.metadata.creationTimestamp
```

## Estrutura de pastas

```text
k8s/
    env.sh
    namespace.yaml
    infrastructure/
        postgresql.yaml
        rabbitmq.yaml
        redis.yaml
    users-api/
        users-api.yaml
    catalog-api/
        catalog-api.yaml
    payments-api/
        payments-api.yaml
    notifications-api/
        notifications-api.yaml
    scripts/
        deploy.sh
        rebuild-images.sh
        reset.sh
        start.sh
        stop-port-forward.sh
```
