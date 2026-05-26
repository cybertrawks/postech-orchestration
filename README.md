# FIAP Cloud Games (FCG) — Orquestração

Repositório central de **GitOps** e **infraestrutura como código** do ecossistema FIAP Cloud Games, projeto desenvolvido para o Tech Challenge da Pós-Tech FIAP — Fase 3.

Este repositório concentra os manifestos Kubernetes de toda a plataforma: infraestrutura de apoio, microsserviços, gateway de API, observabilidade e a função serverless de notificações. Todo o ambiente é declarado aqui e reconciliado continuamente pelo Argo CD.

---

## Visão geral da arquitetura

O FCG é um ecossistema de microsserviços em **.NET 10 / C#** que simula uma loja de jogos digitais. A comunicação entre serviços é **assíncrona**, baseada em eventos, implementando uma **saga coreografada** sobre RabbitMQ com MassTransit.

```
                            ┌──────────────────┐
        Cliente  ───────▶   │  Kong API Gateway │   (JWT validado na borda)
                            └─────────┬────────┘
                                      │
              ┌───────────────┬───────┴───────┬────────────────┐
              ▼               ▼               ▼                ▼
        ┌──────────┐   ┌──────────┐   ┌──────────┐    ┌────────────────┐
        │ Users    │   │ Catalog  │   │ Payments │    │ Notifications  │
        │ API      │   │ API      │   │ API      │    │ API            │
        └────┬─────┘   └────┬─────┘   └────┬─────┘    └────────────────┘
             │              │              │
             └──────────────┴──────┬───────┘
                                   ▼
                       ┌───────────────────────┐
                       │  RabbitMQ (MassTransit)│   saga coreografada
                       └───────────┬───────────┘
                                   │ fila: OrderProcessed-notifications
                                   ▼
                       ┌───────────────────────┐
                       │  KEDA  (escala 0↔N)    │
                       └───────────┬───────────┘
                                   ▼
                       ┌───────────────────────┐
                       │ Notifications Function │   Azure Functions
                       │ (serverless / FaaS)    │   isolated worker .NET 10
                       └───────────┬───────────┘
                                   ▼
                            E-mail (Brevo API)
```

### Componentes

| Camada | Componente | Função |
|---|---|---|
| Gateway | **Kong** | Ponto único de entrada; validação de JWT na borda |
| Microsserviço | **Users API** | Cadastro, autenticação e emissão de JWT |
| Microsserviço | **Catalog API** | Catálogo de jogos e gestão de pedidos |
| Microsserviço | **Payments API** | Processamento de pagamentos |
| Microsserviço | **Notifications API** | Notificações (versão hospedada como serviço) |
| Serverless | **Notifications Function** | Função FaaS acionada por mensagens na fila; envia e-mails |
| Mensageria | **RabbitMQ** | Barramento de eventos da saga (via MassTransit) |
| Dados | **PostgreSQL** | Banco relacional dos microsserviços |
| Dados | **MongoDB** | Armazenamento de notificações |
| Dados | **Redis** | Cache da Catalog API |
| Storage | **Azurite** | Emulador de Azure Storage (requisito do host Azure Functions) |
| Observabilidade | **Prometheus + Grafana** | Métricas e dashboards |
| Autoescala | **KEDA** | Escala a função serverless conforme o tamanho da fila |

### O componente serverless (FaaS)

O requisito de Function as a Service do Tech Challenge é atendido pela **Notifications Function**, implementada como **Azure Functions isolated worker em .NET 10**. Características:

- É **acionada por mensagens** na fila `OrderProcessed-notifications` do RabbitMQ — não recebe tráfego HTTP.
- Permanece em **zero réplicas** quando não há trabalho. Ao chegar uma mensagem, o **KEDA** detecta o tamanho da fila e escala a função de `0` para `1`; após o processamento e o período de _cooldown_, retorna a `0`.
- Ao processar um `OrderProcessedEvent`, dispara o e-mail de "Pagamento Aprovado" através da API da Brevo, com os dados do pedido (jogo e valor) enriquecidos ao longo da saga.
- Usa o **Azurite** como _storage account_, pré-requisito do host do Azure Functions.

Esse desenho — função ociosa em zero, escalada sob demanda por evento de fila — é o modelo serverless literal exigido pelo enunciado.

---

## Plataforma de infraestrutura

O ambiente roda sobre um cluster **Kubernetes** provisionado com `kubeadm` (3 _control planes_ + 3 _workers_). Os componentes de plataforma:

| Função | Tecnologia |
|---|---|
| Orquestração | Kubernetes (kubeadm) |
| Rede (CNI) | Cilium |
| Load Balancer | MetalLB |
| Armazenamento persistente | Longhorn |
| Gestão de segredos | Sealed Secrets |
| Autoescala orientada a eventos | KEDA |
| Entrega contínua (GitOps) | Argo CD |
| Registry e CI | GitLab self-hosted + Container Registry |

### GitOps

Toda mudança de ambiente passa por este repositório. O **Argo CD** observa o repositório e reconcilia o estado do cluster com o que está versionado — nenhum recurso é aplicado manualmente em produção. O fluxo de trabalho é: _commit_ no manifesto → _push_ → Argo CD sincroniza → cluster atualizado.

---

## Estrutura do repositório

A árvore abaixo reflete os caminhos efetivamente sincronizados pelas _Applications_ do Argo CD:

```text
k8s/
  infrastructure/             # PostgreSQL, RabbitMQ, MongoDB, Redis, Azurite
  gamestore/
    users-api/                # Microsserviço de usuários
    catalog-api/              # Microsserviço de catálogo e pedidos
    payments-api/             # Microsserviço de pagamentos
    notifications-api/        # Microsserviço de notificações
    shared/                   # Recursos compartilhados (ex.: secret de pull do registry)
  notifications-function/     # Função serverless + ScaledObject do KEDA
  kong/                       # API Gateway
  monitoring/                 # Prometheus + Grafana
  keda/                       # Instalação do KEDA
  scripts/                    # Scripts auxiliares
```

### Applications do Argo CD

O ambiente é dividido em 10 _Applications_, cada uma sincronizando um caminho deste repositório:

| Application | Caminho |
|---|---|
| `fcg-infrastructure` | `k8s/infrastructure` |
| `fcg-keda` | `k8s/keda` |
| `fcg-kong` | `k8s/kong` |
| `fcg-monitoring` | `k8s/monitoring` |
| `fcg-gamestore-shared` | `k8s/gamestore/shared` |
| `fcg-users-api` | `k8s/gamestore/users-api` |
| `fcg-catalog-api` | `k8s/gamestore/catalog-api` |
| `fcg-payments-api` | `k8s/gamestore/payments-api` |
| `fcg-notifications-api` | `k8s/gamestore/notifications-api` |
| `fcg-notifications-function` | `k8s/notifications-function` |

### Namespaces

| Namespace | Conteúdo |
|---|---|
| `infrastructure` | PostgreSQL, RabbitMQ, MongoDB, Redis, Azurite |
| `gamestore` | Microsserviços .NET e a função serverless |
| `kong` | API Gateway |
| `monitoring` | Prometheus e Grafana |
| `keda` | Operador KEDA |

---

## Repositórios do projeto

Todos publicados no GitHub, sob o usuário `cybertrawks`:

| Repositório | URL | Conteúdo |
|---|---|---|
| `postech-orchestration` | `https://github.com/cybertrawks/postech-orchestration` | Este repositório — manifestos Kubernetes e GitOps |
| `postech-users-api` | `https://github.com/cybertrawks/postech-users-api` | Microsserviço de usuários e autenticação |
| `postech-catalog-api` | `https://github.com/cybertrawks/postech-catalog-api` | Microsserviço de catálogo e pedidos |
| `postech-payments-api` | `https://github.com/cybertrawks/postech-payments-api` | Microsserviço de pagamentos |
| `postech-notifications-api` | `https://github.com/cybertrawks/postech-notifications-api` | Microsserviço de notificações |
| `postech-notifications-function` | `https://github.com/cybertrawks/postech-notifications-function` | Função serverless de notificações (Azure Functions) |
| `postech-shared` | `https://github.com/cybertrawks/postech-shared` | Contratos de eventos compartilhados (pacote NuGet) |

---

## Pré-requisitos

- Cluster Kubernetes acessível (este projeto usa `kubeadm`, mas qualquer cluster compatível serve).
- `kubectl` configurado para o cluster.
- Componentes de plataforma instalados: Cilium, MetalLB, Longhorn, Sealed Secrets, KEDA, Argo CD.
- GitLab com Container Registry para hospedar as imagens dos serviços.

---

## Deploy

O ambiente é entregue via **GitOps** — o Argo CD aplica os manifestos deste repositório. O procedimento abaixo descreve a configuração inicial.

### 1. Componentes de plataforma

Instale, na ordem, os componentes de base do cluster (CNI, load balancer, storage, secrets, autoescala e o próprio Argo CD). O KEDA é versionado neste repositório:

```bash
kubectl apply -f k8s/keda/keda-2.19.0.yaml
```

### 2. Namespaces

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/kong/namespace.yaml
kubectl apply -f k8s/monitoring/namespace.yaml
```

### 3. Segredos

Os segredos são versionados como **Sealed Secrets** (`*-sealedsecret.yaml`) — seguros para manter no Git, pois só o controlador no cluster consegue decifrá-los. O Argo CD os aplica junto dos demais manifestos.

### 4. Applications do Argo CD

Cada camada (infraestrutura, microsserviços, função serverless, gateway, observabilidade) é registrada como uma _Application_ no Argo CD — são 10 ao todo, listadas na seção [Applications do Argo CD](#applications-do-argo-cd). Cada uma aponta para um caminho deste repositório e, a partir do registro, o Argo CD mantém o cluster sincronizado automaticamente.

Atualmente as _Applications_ são criadas pela interface do Argo CD. Uma evolução planejada é versioná-las neste repositório no padrão _app-of-apps_ (ver _Known issues_).

---

## Fluxo de uma compra (validação ponta a ponta)

A jornada que exercita todo o ecossistema:

1. O cliente autentica na **Users API** (via Kong) e recebe um JWT.
2. Com o JWT, cria um pedido na **Catalog API**.
3. A **Payments API** processa o pagamento e publica um evento na saga.
4. O evento percorre a cadeia de serviços, sendo **enriquecido** com nome do jogo e valor.
5. O `OrderProcessedEvent` final chega à fila `OrderProcessed-notifications` no RabbitMQ.
6. O **KEDA** detecta a mensagem e escala a **Notifications Function** de `0` para `1`.
7. A função consome o evento e envia o e-mail de "Pagamento Aprovado" via Brevo.
8. Concluído o processamento, o KEDA retorna a função a `0` réplicas.

---

## Observabilidade

Métricas dos microsserviços e da plataforma são coletadas pelo **Prometheus** e visualizadas no **Grafana**, ambos no namespace `monitoring`.

---

## Known issues / melhorias futuras

- **Estrutura de manifestos legada** — as pastas `k8s/catalog-api/`, `k8s/payments-api/`, `k8s/users-api/` e `k8s/notifications-api/` (sem o nível `gamestore/`) não são usadas por nenhuma _Application_ do Argo CD — a árvore ativa é `k8s/gamestore/<serviço>/`. As pastas legadas devem ser removidas.
- **Definições de Application do Argo CD não versionadas** — as 10 _Applications_ foram criadas diretamente na interface do Argo CD; adotar o padrão _app-of-apps_ para versioná-las neste repositório.
- **Filas dedicadas criadas imperativamente** — as filas `OrderProcessed-notifications` e `UserCreated-notifications` foram criadas manualmente no RabbitMQ; devem ser versionadas (`definitions.json`).
- **Arquivos de runtime versionados** — `k8s/.runtime/` (logs de _port-forward_, PIDs) não deveria estar sob controle de versão; adicionar ao `.gitignore`.
- **Cobertura de testes** — `payments-api` e `notifications-api` ainda sem testes automatizados.
- **README legado de submódulos** — `k8s/gamestore/users-api/README.md` reflete organização antiga.

---

## Tech Challenge — Fase 3

Este repositório é parte da entrega da Fase 3 da Pós-Tech FIAP. Os requisitos cobertos:

- **Microsserviços** desacoplados comunicando-se de forma assíncrona.
- **Função serverless (FaaS)** acionada por mensagens em fila, com autoescala.
- **Infraestrutura como código** — todo o ambiente declarado em manifestos versionados.
- **Observabilidade** — métricas e dashboards.
- **Entrega contínua via GitOps** — reconciliação automática pelo Argo CD.
