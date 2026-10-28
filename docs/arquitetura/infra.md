# Agenor 2.0: o que o código precisa do ambiente

Aqui está só o que o DC v2, o Launcher e os workers precisam encontrar no ambiente. A forma de entregar cada item (chart, values, pipeline, Secrets) não faz parte deste documento.

Os ambientes (DEV, STG, PRD) são a última etapa (fase 6). Até lá, tudo roda no ambiente local, com as peças da coluna "Local". A lista de pedidos ao cliente, com a numeração usada abaixo, está no plano (§3.10, parte B).

**Situação:** **definido** = valor ou nome já fixado no código ou nos ADRs; **a definir** = o nome sai na atividade indicada, e este arquivo é atualizado junto; **cliente** = depende de pedido ao cliente.

## Resumo

| # | O que precisamos | Para quê | Local | Ambientes |
|---|---|---|---|---|
| 1 | [Banco](#banco): o Postgres do DC atual, com o schema `agenor_v2` | Estado do 2.0 | Postgres local com o esquema do DC atual | Mesmo banco do DC atual |
| 2 | [Fila](#fila) nova para o 2.0 | Pedido de execução DC → Launcher | Adaptador local | OCI Queue nova por ambiente (pedido 3) |
| 3 | [Bucket](#bucket) | Arquivos, planilhas e JSON das extrações | Armazenamento local compatível com S3 | Bucket OCI do Agenor, como hoje |
| 4 | [Cluster e permissões](#cluster-e-permissões) | Launcher criar os Jobs | kind ou k3d | Namespace, ServiceAccount e Role (pedidos 1 e 2) |
| 5 | [Usuários de serviço do Agnaldo](#autenticação) | Autenticação entre serviços | Os que já temos | Por ambiente (pedido 6) |
| 6 | [Imagens](#imagens) | Launcher e workers | Build local | Harbor (pedido 4) |
| 7 | [Rede](#rede) | Saída dos workers e acesso ao DC | Sem restrição | NetworkPolicies (pedido 9) |
| 8 | [Recursos](#recursos) | Dimensionar os Jobs | Máquina local | ResourceQuota e nós (pedidos 1 e 8) |
| 9 | [Observabilidade](#observabilidade) | Traces, métricas e logs | Opcional | Alloy, ServiceMonitor, coleta de logs (pedido 13) |
| 10 | [Acessos externos](#acessos-externos) | Coleta nos portais | Acessos de teste | Os de produção, como hoje |

## Banco

O mesmo Postgres do DC atual (`hiperautomacao_document_collector_<ambiente>`). Decisão no [ADR-001](adr-001-isolamento-no-schema-agenor-v2.md).

- O DC v2 usa **só o schema `agenor_v2`**, com a `alembic_version` dentro dele.
- O usuário do DC v2 precisa criar o schema na primeira migração, ou o schema precisa já existir com esse usuário como dono. Permissão no `public` não é necessária.
- As migrações rodam numa **etapa separada, antes do deploy**: um Job com a mesma imagem do DC v2 e o comando `python -m app.migrate`, que exige só as variáveis `POSTGRES_*` (pedido 10). O pod do DC v2 não roda migração ao subir. Como o Job é disparado (por exemplo, um hook do Helm) é decisão do cliente. No local: `local/k8s/dc-v2.yaml`.
- Se o schema `agenor_v2` for criado antes por um DBA, com o usuário do DC v2 como dono, esse usuário não precisa de `CREATE` no banco.
- O DC atual continua subindo e rodando `alembic upgrade head` sobre o `public`, sem mudança.

| Variável (DC v2) | Situação |
|---|---|
| `POSTGRES_SERVER`, `POSTGRES_PORT`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` | Definido (herdado do DC atual). A senha vem de Secret |
| `POSTGRES_ESTABLISHMENT_BRANCH_*` | Definido (herdado). Banco do company-service, com usuário somente leitura em Secret (pedido 11) |

## Fila

Uma fila nova para o 2.0 em cada ambiente. **Não é a fila que o scraper consome hoje**: se fosse, o scraper pegaria as mensagens do 2.0. Decisão no [ADR-004](adr-004-despachante-e-retentativa.md).

| Configuração | Valor |
|---|---|
| Visibilidade | 15 min |
| Retenção | 7 dias |
| Entregas | no máximo 3, depois DLQ |
| Canais | um só (sem canal por tipo) |

Permissões: o DC v2 **publica** (`PutMessages`); o Launcher **consome** (`GetMessages`, `UpdateMessage`, `DeleteMessage`).

Credencial: API key de usuário OCI, num Secret **montado como arquivo** no DC v2 e no Launcher: o `config` no formato do OCI SDK e a chave `.pem` (pedido 7).

| Variável (DC v2 e Launcher) | Situação |
|---|---|
| `QUEUE_PROVIDER` (`oci` nos ambientes; `local` só no ambiente local) | Definido (A1.17) |
| `OCI_QUEUE_ID` e `OCI_QUEUE_ENDPOINT` (`https://cell-1.queue.messaging.sa-saopaulo-1.oci.oraclecloud.com`) | Definido (A1.17). Apontam para a fila nova, não para a do DC atual (`OCI_AGENOR_QUEUE_ID`) |
| `OCI_CONFIG_FILE` (caminho do `config` montado do Secret, que aponta para a `.pem`) e `OCI_CONFIG_PROFILE` (padrão `DEFAULT`) | Definido (A1.17) |

## Bucket

O bucket OCI do Agenor (`hiperautomacao-agenor-<ambiente>`), pela API compatível com S3, como hoje. Chave dos objetos no [ADR-007](adr-007-workers-por-tipo-com-base-comum.md).

- Os **workers** gravam arquivos, planilhas e o JSON das extrações. O worker **ZIP** lê os arquivos da coleta e grava o ZIP.
- O **DC v2** lê, para listar e baixar.

| Variável | Quem usa | Situação |
|---|---|---|
| `AWS_FILES_BUCKET`, `AWS_REGION`, `AWS_URL_ENDPOINT` | DC v2 | Definido (herdado) |
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | DC v2 | Definido (herdado), em Secret |
| As mesmas, no `core` dos workers | Workers | A definir (fase 3) |

## Cluster e permissões

O Launcher cria um Kubernetes Job por tentativa. Decisão no [ADR-005](adr-005-launcher-com-kubernetes-jobs.md).

- **Namespace dos workers**, com ResourceQuota (pedido 1).
- **ServiceAccount e Role do Launcher**, só nesse namespace (pedido 2):

  | Recurso | Verbos |
  |---|---|
  | `jobs` (`batch`) | `create`, `get`, `list`, `watch`, `delete` |
  | `pods` | `get`, `list`, `watch`, `delete` |
  | `pods/log` | `get` |

- Os Jobs rodam **sem root**, com `restartPolicy: Never`, `backoffLimit: 0`, `activeDeadlineSeconds` do catálogo e `ttlSecondsAfterFinished`.
- O Launcher roda com **1 réplica**. Não precisa de banco nem de volume.

| Variável (Launcher) | Situação |
|---|---|
| `LAUNCHER_PORT` (health e métricas; padrão 9093), `LAUNCHER_LOG_LEVEL` | Definido (esqueleto) |
| Namespace dos workers, teto de segurança de Jobs, caminho do catálogo de tipos | A definir (fase 2) |
| URL do DC v2 | A definir (fase 2) |

## Autenticação

Usuários de serviço do Agnaldo, um por serviço. Decisão no [ADR-006](adr-006-autenticacao-por-usuario-de-servico-do-agnaldo.md).

- O Launcher e os workers recebem a credencial do seu usuário de serviço por Secret e obtêm o token em `POST /auth/token`. O token fica em memória.
- O token é obtido com `POST /api/v1/auth/token` **em formulário** (`username`, `password`).
- O DC v2 valida o token localmente, pelo JWKS do realm do SSO (A1.2, ADR-006). Precisa alcançar o SSO (`AUTH_ISSUER`), não o Agnaldo.
- Cada ambiente precisa de um usuário de serviço para o Launcher e um para os workers (pedido 6).

| Variável | Quem usa | Situação |
|---|---|---|
| URL do Agnaldo, usuário e senha do usuário de serviço | Launcher e workers | A definir (fase 2 e fase 3) |
| `AUTH_ISSUER` (ex.: `https://sso.agnes.com.br/realms/agnes`) e, opcional, `AUTH_JWKS_URL` | DC v2 | Definido (A1.2) |
| `AUTH_WORKER_USERS` e `AUTH_LAUNCHER_USERS`: nomes dos usuários de serviço, separados por vírgula | DC v2 | Definido (A1.2). Os nomes dependem do pedido 6 |

## Imagens

Repositórios no Harbor (pedido 4):

| Repositório | Conteúdo |
|---|---|
| `agenor-launcher` | Launcher |
| `agenor-worker` | Workers HTTP (todos, exceto DCTF) e ZIP |
| `agenor-worker-chrome` | Worker DCTF (HTML→PDF) |

O DC v2 usa uma imagem própria, separada da do DC atual (A1.4): `Dockerfile` do repositório, sem root (uid 10001), na porta 9092. A mesma imagem serve à API (padrão) e ao Job de migração (`python -m app.migrate`). Enquanto o `agenor-common` é instalado pelo caminho local, o build exige `--build-context agenor-common=../agenor-common`; com a tag Git publicada, deixa de exigir.

**Entrada de cada Job,** definida pelo Launcher como variáveis de ambiente (definido, `core/settings.py`):

| Variável | Conteúdo |
|---|---|
| `ATTEMPT_ID` | Tentativa |
| `COLLECTED_ID` | Coleta |
| `COLLECTION_TYPE` | Tipo de coleta |

O resto da entrada (cliente, procurador, filtros) o worker busca no DC v2. Nenhum dado fiscal ou pessoal vai na definição do Job.

## Rede

| De | Para | Porta |
|---|---|---|
| DC v2 | Postgres, bucket, OCI Queue, Agnaldo | as de hoje |
| Launcher | API do Kubernetes, OCI Queue, DC v2 | 443 e a porta do DC |
| Workers | DC v2, Agnaldo, bucket | HTTPS e a porta do DC |
| Workers | Portais da Receita, via proxies Soax e Oxylabs | HTTPS |
| Worker Créditos DCTFWeb | Moon | a de hoje |
| Worker DARF | session-manager e resolvedor de hCaptcha | HTTPS |

A saída dos workers fica restrita a esses destinos por NetworkPolicy (pedido 9).

## Recursos

Começamos com os valores atuais do scraper e com no máximo **6 coletas simultâneas** (Créditos DCTFWeb até 4, pelo limite do Moon). O tempo máximo inicial é o de hoje, até 4 h. CPU, memória e tempo por tipo ficam no catálogo do Launcher e são calibrados com as métricas do 2.0, primeiro local e depois em STG.

O namespace precisa comportar o teto de segurança do Launcher mais o Job do ZIP (pedido 8).

## Observabilidade

Decisão no [ADR-008](adr-008-observabilidade.md).

| Item | Quem | Situação |
|---|---|---|
| `OTEL_EXPORTER_OTLP_ENDPOINT` (Alloy) e `OTEL_SERVICE_NAME` | DC v2, Launcher e workers | A definir (A1.14). O DC atual usa `OPEN_TELEMETRY_ENDPOINT` |
| ServiceMonitor em `/metrics` | DC v2 e Launcher | Cliente (pedido 13) |
| Coleta dos logs dos Jobs antes da limpeza | Workers | Cliente (pedido 13) |

Logs em JSON, com `collected_id`, `attempt_id` e o nome do Job em toda linha.

## Acessos externos

| Acesso | Quem usa | Local | Ambientes |
|---|---|---|---|
| Procurador, certificado e CNPJs de teste | Workers | Pedido A2, antes do piloto (A0.8) | Os de produção |
| Proxies Soax e Oxylabs | Workers | Pedido A3, antes do piloto (A0.8) | Credenciais em Secret (pedido 7) |
| Moon | Créditos DCTFWeb | Pedido A4, fase 4 | Como hoje |
| session-manager e hCaptcha | DARF | Pedido A4, fase 4 | Credenciais em Secret (pedido 7) |

## Versão

O DC v2, o Launcher e os workers usam a mesma tag do `agenor-common`: o evento da fila e os modelos da API mudam juntos. Um deploy que muda o contrato sobe o DC v2 primeiro, desde que ele aceite as duas versões do evento durante a troca.

## Como saber que está no ar

| Onde | O que verificar |
|---|---|
| DC v2 | Health check verde (`/api/v1/health/`); o Job de migração terminou; o DC atual continua subindo |
| Launcher | Health check verde (consumindo a fila e falando com a API do Kubernetes) |
| Workers | Uma coleta de teste cria uma tentativa, um Job no namespace dos workers e termina com os arquivos no bucket |

Este arquivo é atualizado a cada atividade que fixa um nome ou valor marcado como "a definir".
