# Ambiente Local k8s-like com Docker Compose

Este diretório sobe uma stack local espelhando o ambiente Kubernetes:

- PostgreSQL
- RabbitMQ
- Redis
- users-api
- catalog-api
- payments-api
- notifications-api

## Dependências

- Docker Desktop (ou Docker Engine)
- Docker Compose
- Imagens das APIs disponíveis localmente ou em registry acessível pelo Docker local

Por padrão, as imagens esperadas são:

- `postech/users-api:local`
- `postech/catalog-api:local`
- `postech/payments-api:local`
- `postech/notifications-api:local`

Se você usa outro prefixo/tag:

```bash
export DOCKER_USER=seu-usuario
export IMAGE_TAG=sua-tag
```

As variaveis sao centralizadas em `postech-orchestration/.env`.
Se nao existir, o script `scripts/start-complete.sh` cria automaticamente
o arquivo a partir de `postech-orchestration/.env.example`.

## Comandos principais

### Subir tudo

```bash
cd temp
docker compose up -d
```

Ou usando o script (recomendado):

```bash
cd temp
bash scripts/start-complete.sh
```

### Ver status

```bash
cd temp
docker compose ps
```

### Ver logs

```bash
cd temp
docker compose logs -f users-api
```

### Parar ambiente

```bash
cd temp
docker compose down
```

### Reset completo (remove volumes)

```bash
cd temp
docker compose down -v
```

## Endpoints

### APIs

- Users: `http://localhost:8081`
- Catalog: `http://localhost:8082`
- Payments: `http://localhost:8083`
- Notifications: `http://localhost:8084`

Rotas Scalar (quando habilitadas na API):

- Users: `http://localhost:8081/scalar/v1`
- Catalog: `http://localhost:8082/scalar/v1`
- Payments: `http://localhost:8083/scalar/v1`
- Notifications: `http://localhost:8084/scalar/v1`

### Infra

- PostgreSQL: `localhost:5432`
- RabbitMQ AMQP: `localhost:5672`
- RabbitMQ UI: `http://localhost:15672`
- Redis: `localhost:6379`

## Exemplo de uso integrado

Fluxo comum para validar imagens e stack local:

```bash
# 1) (Opcional) build de imagens no fluxo k8s
cd ../k8s/scripts
bash rebuild-images.sh

# 2) subir stack local k8s-like
cd ../../temp
docker compose up -d

# 3) validar containers e logs
docker compose ps
docker compose logs -f payments-api
```

## Observações

- Os aliases de rede internos simulam DNS de Kubernetes (`*.infrastructure.svc.cluster.local`).
- Isso permite reaproveitar as mesmas variáveis de host usadas nos manifests do cluster.
