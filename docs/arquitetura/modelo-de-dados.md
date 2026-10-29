# Modelo de dados do `agenor_coleta`

- **Status:** aprovado pelo Lucas em 29/10 (A1.3b). Descreve o `app/models/agenor_coleta.py` e a revisão head do DC v2 (`20261029_a057fe7dbe85_agenor_coleta_inicial.py`), e muda junto com eles.
- **Origem:** ADR-001 (isolamento), ADR-002 (tentativa e status), ADR-003 (contratos), ADR-004 (despachante e retentativa), ADR-007 (ZIP e extração) e o modelo da A1.3 (revisão `9fd63faacdde`, feita sem esta etapa e substituída pela `a057fe7dbe85`).

## Para que serve este documento

É o catálogo do schema `agenor_coleta`: para cada tabela e coluna, para que serve, quem escreve, quem lê e o que substitui no `public`. **Toda tabela ou coluna entra aqui antes de entrar no modelo e na migração.**

É um documento, e não um ADR, porque muda a cada migração. As decisões que saem dele (por que algo é derivado, por que algo ficou de fora) vão para o ADR que elas afetam.

### Critério: só o que a arquitetura precisa agora

- Uma coluna existe se um fluxo definido hoje a escreve **e** a lê: a API do worker e do Launcher (ADR-003), o despachante, a retentativa e o abandono (ADR-004) e a regra de status (ADR-002).
- O contrato que o front usa hoje (`contrato/consumidor-dc-atual.openapi.json`) é **referência, não requisito**. Um campo dele só vira coluna quando a API do consumidor (A1.16) for detalhada e um fluxo precisar dele. Até lá, ele aparece abaixo como **derivado** (sai do que já existe) ou **fora agora**.
- **O modelo é inicial e vai mudar.** O fluxo completo do consumidor, o ZIP (fase 4) e a extração por tipo ainda não estão detalhados. Cada parte, quando for detalhada, cria, corrige ou remove colunas por migração, e passa por aqui antes.

### Estado na coluna, histórico no evento

- **Coluna:** o estado que um fluxo consulta para decidir (status, hora de retentativa, despachada ou não, último sinal de vida).
- **`event`:** quando e onde algo aconteceu (Job criado, pod e versão do worker, início, fim, mudança de status). O histórico já é uma decisão do ADR-002, e o evento leva os detalhes em `metadata`.
- Um dado que só serviria para diagnóstico não vira coluna: vai no evento. Se um fluxo passar a consultá-lo, ele sobe para coluna por migração.

## Quem escreve e quem lê

| Ator | O que é | Como chega ao banco |
|---|---|---|
| **Consumidor** | Front do Agenor e outros, pelo Agnaldo/APISIX | API do consumidor do DC (A1.16) |
| **DC** | Regras do DC v2: criação da coleta, cálculo do status (A1.7), retentativa (A1.9), histórico (A1.11) | Direto, como único escritor |
| **Despachante** | Parte do DC: publica o que pode rodar (A1.8) | Direto |
| **Varredura** | Parte do DC, a cada 1 min: retentativas, republicação e abandono (A1.8, A1.10) | Direto |
| **Launcher** | Cria o Job e informa como ele terminou (ADR-005) | `POST /api/v2/attempts/{id}/infra-event` |
| **Worker** | Executa a tentativa (ADR-007) | `/api/v2/attempts/{id}/...` |

Só o DC grava no banco. "Worker escreve" quer dizer que o DC grava o que o worker informou pela API.

```text
collection 1 ── N attempt        no máximo uma ativa por coleta
collection 1 ── N item           chave única dentro da coleta; aponta para a tentativa que o informou por último
collection 1 ── N event          attempt_id opcional
```

## Decisões desta modelagem

Os pontos levantados na #341, cada um com a recomendação aprovada em 29/10 e aplicada na revisão `a057fe7dbe85`.

### 1. Contagens de falha: derivadas das tentativas

`collection.technical_failures` e `business_retries` contam o que já está em `attempt`: duas fontes da verdade para a mesma decisão.

**Decisão: saem.** A retentativa (A1.9) conta na hora em que uma tentativa termina:

- falhas técnicas: tentativas da coleta com `INFRA_FAILED` ou `TIMED_OUT` (o abandono termina em `INFRA_FAILED`);
- retentativas de negócio: tentativas com `NO_SESSION` ou `FAILED` com `recoverable = true`. A espera seguinte (5, 15, 30, 60 min…) sai desse número.

É uma consulta pequena (uma coleta tem poucas tentativas), pelo índice de `(collection_id, number)`. Ela roda com a linha da coleta travada (`SELECT … FOR NO KEY UPDATE`, que não bloqueia quem só insere itens ou eventos da coleta), a mesma trava que serializa o fim da tentativa, o aviso do Launcher e o abandono da mesma coleta. Assim, não há contador para ficar fora de sincronia. ADR-004 ganha essa regra.

### 2. `request_payload`: sai

Repete `collection_type`, `client_document`, `power_of_attorney_document`, `data_filters` e `force`, que são a entrada do worker. No DC atual, o front lia o pedido inteiro de volta; se a A1.16 precisar disso, ele é remontado dessas colunas (**derivado**).

### 3. Um tipo só; o ZIP fica para quando for detalhado

Hoje há dois enums de tipo: `collection.collection_type` (os 9 tipos do consumidor) e `attempt.attempt_type` (os mesmos 9 mais `ZIP`, do `agenor_common`). A única razão do segundo é o ZIP como tentativa de outro tipo na mesma coleta (ADR-007).

**O ZIP continua sendo um worker** (ADR-007): gerar o ZIP prende a requisição e o pod do DC por minutos, que é o problema que motivou a decisão. O que não está decidido é **como ele se liga à coleta**: tentativa da mesma coleta (e então disputa a regra de "uma ativa por coleta", entra ou não nas contagens da decisão 1 e no cálculo do status) ou entidade própria. Isso se decide na fase 4, quando o ZIP for detalhado.

**Decisão:**

- `attempt.attempt_type` sai. O tipo da tentativa é o da coleta; o despachante agrupa por `collection.collection_type` com um join pela chave da coleta.
- `collection.zip_file_key` sai (**fora agora**, volta com o ZIP). Com ele, sai o "download disponível".
- O valor `ZIP` continua no `agenor_common.api.CollectionType` (contrato do evento e do catálogo do Launcher). Nenhuma linha do `agenor_coleta` o usa até a fase 4. Se o ZIP virar tentativa da mesma coleta, a coluna provável é um "estágio" da tentativa (`COLLECT` ou `ZIP`), e não um segundo tipo.

### 4. Job, pod, versão e horários da tentativa: evento

`attempt.job_created_at`, `job_name`, `pod_name`, `worker_version`, `started_at` e `finished_at` não são lidos por nenhum fluxo:

- o abandono usa o status (`RUNNING` quer dizer que o worker começou), `dispatched_at` e `last_heartbeat_at` (gravado também no `start`);
- o nome do Job é determinístico (tipo e `attempt_id`, ADR-005) e o Launcher reconcilia pelos labels do Kubernetes, não pelo DC;
- a próxima tentativa recebe `not_before` no momento do fim; nada consulta a hora do fim depois.

**Decisão: saem da tabela e vão para o evento.** `attempt.job_created` (autor `SYSTEM`, com `job_name`), `attempt.started` (`ROBOT`, com `job_name`, `pod_name` e `worker_version`) e `attempt.finished` (com o resultado). A API não muda: o `StartRequest` continua mandando os três campos, e o DC os grava no evento. Se as métricas da A1.14 precisarem das durações por etapa, elas são registradas no momento de cada transição, sem consultar o banco.

### 5. `item.report_type`: texto, sem catálogo

No `public`, o `report_type` é um catálogo (`name`, `description`, `endpoint_url`) referenciado por chave estrangeira em cada execução, ligado às rotas antigas por tipo. No 2.0, quem sabe quais documentos existem em cada tipo de coleta é o worker (ele planeja os itens, ADR-007). Um catálogo no DC faria cada documento novo de um coletor depender de uma migração do DC.

**Decisão:** `report_type` continua como texto informado pelo worker, sem catálogo. Os valores de cada tipo ficam no worker, documentados quando cada coletor for portado (fase 4). Se a A1.16 precisar de nome legível ou de filtro por documento, isso é decidido lá.

### 6. Campos que o front de hoje lê e o modelo não tem

Ver [a lista abaixo](#campos-do-contrato-do-front-que-o-modelo-não-tem): nenhum vira coluna agora.

### 7. Transversais

- **`updated_at` sai da `collection` e da `attempt`.** Nenhum fluxo lê "quando a linha mudou", e as mudanças delas ficam no evento. O `item` mantém o seu: não há evento por item, então o `updated_at` é o único registro de quando uma tentativa o informou por último.
- **Índices sem leitor saem.** Os três índices de listagem da `collection` (por cliente, por status e por data) e os índices das chaves estrangeiras `item.attempt_id` e `event.attempt_id` não servem a nenhuma consulta definida. A A1.16 cria os índices das consultas que ela tiver.
- **Status continuam texto com `CHECK` nomeado** (ADR-001).

## Tabelas

Legenda da coluna "Muda", em relação ao modelo da A1.3: **=** ficou; **sai**; **muda**. As linhas riscadas estão aqui só para registrar o que saiu.

### `collection`: a coleta pedida pelo consumidor

Uma linha por pedido. A entrada não muda depois de criada; o status é só do DC.

| Coluna | Tipo | Para que serve | Escreve | Lê | No `public` | Muda |
|---|---|---|---|---|---|---|
| `id` | uuid, PK | Identifica a coleta (`collected_id` no evento da fila e nas APIs) | DC | todos | `collected.id` | = |
| `collection_type` | texto(32) + CHECK (9 tipos do consumidor) | Qual worker roda; agrupa a capacidade do despachante | Consumidor | Despachante, worker (`input`) | `collected.collection_type` | = |
| `client_document` | texto(14) | CNPJ do cliente | Consumidor | Worker (`input`) | `collected.client_document` | = |
| `power_of_attorney_document` | texto(14) | CNPJ ou CPF do procurador (certificado). Obrigatório: sem ele, o worker não abre sessão | Consumidor | Worker (`input`) | `collected.power_of_attorney_document` (lá, opcional) | = |
| `data_filters` | jsonb, padrão `{}` | Filtros do pedido, já normalizados pelo DC | Consumidor (DC normaliza) | Worker (`input`) | parte do `collected.request_payload` | = |
| `force` | boolean, padrão `false` | Coletar de novo os itens já concluídos | Consumidor | Worker (`input`, decide se pula os concluídos) | query `force` do POST, não era gravado | = |
| `request_user_id` | texto(256) | Quem pediu: a única auditoria do pedido de dados fiscais | Consumidor (header) | Auditoria; filtro da A1.16 | `collected.request_user_id` | = |
| `request_user_name` | texto(512), opcional | Nome de quem pediu, junto do id | Consumidor (header) | Auditoria | `collected.request_user_name` | = |
| `status` | texto(32) + CHECK (`CollectedStatus`, os 8 de hoje), padrão `PENDING` | Status da coleta | DC (A1.7), único escritor | Consumidor | `collected.status` | = |
| `status_text` | texto, opcional | Status legível, com o motivo (ADR-002) | DC (A1.7) | Consumidor | `failure_reason`, que o DC atual derivava dos eventos | = |
| `cancelled_at` | timestamptz, opcional | Marca a coleta como cancelada: o status não tem `CANCELLED`. O `input` e o `heartbeat` respondem `active = false`, e a retentativa não cria nova tentativa | DC (cancelamento; a chamada ainda não existe no contrato do consumidor, entra com a A1.16 ou o cenário de cancelamento da A2.10) | DC (A1.5, A1.9) | — | = |
| `created_at` | timestamptz, padrão `now()` | Hora do pedido | DC | Consumidor | `collected.created_at` | = |
| ~~`request_payload`~~ | | | | | | sai (decisão 2) |
| ~~`technical_failures`~~, ~~`business_retries`~~ | | | | | | sai (decisão 1) |
| ~~`zip_file_key`~~ | | | | | | sai (decisão 3) |
| ~~`finished_at`~~ | | Hora em que a coleta chegou a um status final | | | `collected.finished_at` | sai: evento `collection.status_changed` |
| ~~`updated_at`~~ | | | | | | sai (decisão 7) |

Índices: só a chave primária (decisão 7).

### `attempt`: cada execução da coleta, e a fila de verdade

Uma linha por vez que o DC manda executar a coleta (ADR-002). É também o que o despachante consulta (ADR-004).

| Coluna | Tipo | Para que serve | Escreve | Lê | No `public` | Muda |
|---|---|---|---|---|---|---|
| `id` | uuid, PK | `attempt_id` da fila, do Job, dos logs e de toda chamada do worker | DC | todos | `collection_attempt.id` | = |
| `collection_id` | uuid, FK `collection` | A coleta | DC | todos | `collection_attempt.collected_id` | = |
| `number` | int, único com `collection_id` | Ordem da tentativa na coleta | DC | Worker (`input.attempt_number`), retentativa | `collection_attempt.attempt_number` | = |
| `status` | texto(32) + CHECK (`AttemptStatus`), padrão `QUEUED` | Ciclo da tentativa (ADR-002) | DC, a partir do Launcher, do worker e da varredura | Despachante, abandono, retentativa, A1.7 | `collection_attempt.status` (outros valores) | = |
| `not_before` | timestamptz, padrão `now()` | Hora a partir da qual pode ser despachada: a espera da retentativa. O padrão deixa a primeira tentativa pronta para despachar na hora | DC (A1.9) | Despachante | `collection_attempt.next_attempt_at` | = |
| `dispatched_at` | timestamptz, opcional | Publicada na fila e confirmada. Vazia: falta publicar | Despachante | Despachante (vagas e republicação), abandono (60 min sem início) | `collection_attempt.queued_at` | = |
| `last_heartbeat_at` | timestamptz, opcional | Último sinal de vida (gravado também no `start`) | Worker (`start`, `heartbeat`) | Abandono (5 min) | — | = |
| `error_code` | texto(64), opcional | Código tipado do erro (do worker) ou o tipo de falha (do Launcher ou do abandono) | Worker (`finish`), Launcher, varredura | A1.7 (`status_text`) | — | = |
| `error_message` | texto, opcional | Mensagem do erro | Worker, Launcher, varredura | A1.7 (`status_text`) | `collection_attempt.error_message` | = |
| `recoverable` | boolean, opcional | `FAILED` recuperável conta como retentativa de negócio; não recuperável leva a coleta a `FAILED` | Worker (`finish`) | Retentativa (A1.9) | marcação do `collection_error_map`, no scraper | = |
| `created_at` | timestamptz, padrão `now()` | Ordem de despacho ("em ordem de criação", ADR-004) | DC | Despachante | `collection_attempt.created_at` | = |
| ~~`attempt_type`~~ | | | | | | sai (decisão 3) |
| ~~`job_created_at`~~, ~~`job_name`~~, ~~`pod_name`~~, ~~`worker_version`~~, ~~`started_at`~~, ~~`finished_at`~~ | | | | | | sai: evento (decisão 4) |
| ~~`updated_at`~~ | | | | | | sai (decisão 7) |

Regras no banco:

- **Uma ativa por coleta:** índice único parcial em `collection_id` onde `status IN ('QUEUED', 'STARTING', 'RUNNING')` (ADR-002). =
- **Prontas para despachar:** índice parcial em `not_before` onde `status = 'QUEUED' AND dispatched_at IS NULL`. **muda:** sem `attempt_type`.
- **Em voo:** índice parcial em `collection_id` onde `dispatched_at IS NOT NULL AND status IN ('QUEUED', 'STARTING', 'RUNNING')`, para as vagas por tipo (com o join na coleta) e o abandono. **muda:** sem `attempt_type`.

### `item`: documento ou competência coletada

Uma linha por item da coleta, pela chave que o worker dá. Uma nova tentativa atualiza o mesmo item, não duplica (ADR-002).

| Coluna | Tipo | Para que serve | Escreve | Lê | No `public` | Muda |
|---|---|---|---|---|---|---|
| `id` | bigint, PK | Identificador interno | DC | — | `collection_execution.id` | = |
| `collection_id` | uuid, FK `collection` | A coleta; a chave é única dentro dela | Worker (via tentativa) | `done-items`, A1.7 | `collection_execution.collected_id` | = |
| `attempt_id` | uuid, FK `attempt` | Última tentativa que informou o item: qual execução gravou o arquivo | Worker (`items`) | Diagnóstico | — | = (sem índice, decisão 7) |
| `key` | texto(255), único com `collection_id` | Chave idempotente do item (ex.: `2024-01/recibo`) | Worker | Worker (`done-items`, para pular) | — (o DC atual inseria de novo a cada execução) | = |
| `status` | texto(32) + CHECK (`ItemStatus`) | Resultado do item | Worker | A1.7, `done-items` | `collection_execution.status` | = |
| `report_type` | texto(250), opcional | Documento coletado, nos termos do worker | Worker | Consumidor (A1.16) | `collection_execution.report_type_id` → `report_type.name` | = (decisão 5) |
| `competence` | texto(32), opcional | Competência ou período do item | Worker | Consumidor (A1.16) | `collection_execution.competence` | = |
| `file_key` | texto(1024), opcional | Chave do arquivo no bucket (ADR-007) | Worker | `done-items`, download (A1.16) | `collection_execution.uri_files` | = |
| `extraction_key` | texto(1024), opcional | Chave do JSON da extração no bucket (ADR-007) | Worker | Consumo das extrações (fase 5) | as tabelas `*_extract` | = |
| `error_message` | texto, opcional | Motivo de um item `FAILED` ou `FILE_NOT_FOUND` | Worker | A1.7 (`status_text`), consumidor | `collection_execution.error_message` | = |
| `metadata` | jsonb, padrão `{}` | Dados do item próprios de cada tipo (ex.: versão e identificador do arquivo do DCTF) | Worker | Consumidor, quando o tipo for detalhado | `collection_execution.tipo_versao_documento`, `identificador_arquivo`, `file_id` | = |
| `created_at` | timestamptz, padrão `now()` | Primeira vez que o item foi informado | DC | Diagnóstico | `collection_execution.created_at` | = |
| `updated_at` | timestamptz, padrão `now()` | Última vez que uma tentativa informou o item (não há evento por item, decisão 7). O `onupdate` do modelo não vale num `INSERT … ON CONFLICT DO UPDATE`: o upsert da A1.6 grava `updated_at = now()` explicitamente | DC | Diagnóstico | — | = |

`report_type`, `competence`, `error_message` e `extraction_key` ficam como colunas, e não no `metadata`, porque fazem parte do contrato do worker já definido (`ItemReport`, A1.1): são o resultado da coleta, com tipo e tamanho validados, e não diagnóstico.

### `event`: histórico

No formato do Agnes Collector (ADR-002). Guarda o que saiu das colunas pela regra "estado na coluna, histórico no evento".

| Coluna | Tipo | Para que serve | Escreve | Lê | No `public` | Muda |
|---|---|---|---|---|---|---|
| `id` | bigint, PK | Ordem de gravação | DC | — | `*_events.id` | = |
| `collection_id` | uuid, FK `collection` | A coleta | DC | Consumidor (histórico), diagnóstico | `collected_status_events.collected_id` | = |
| `attempt_id` | uuid, FK `attempt`, opcional | A tentativa, quando o evento é dela | DC | Diagnóstico | — | = (sem índice, decisão 7) |
| `category` | texto(32) | `collection` ou `attempt` (sem evento por item) | DC | Consumidor, diagnóstico | `property_changed` | = |
| `name` | texto(100) | Nome com ponto (`attempt.started`) | DC | Consumidor, diagnóstico | — | = |
| `message` | texto | Mensagem legível | DC | Consumidor | `property_reason` | = |
| `author` | texto(32) + CHECK (`ROBOT`, `USER`, `SYSTEM`) | Worker, consumidor ou o próprio DC e o Launcher | DC | Consumidor | — | = |
| `metadata` | jsonb, padrão `{}` | Detalhes (status antigo e novo, Job, pod, versão, erro) | DC | Diagnóstico | `old_value`, `new_value` | = |
| `created_at` | timestamptz, padrão `now()` | Quando aconteceu (hora da transação; eventos da mesma transação desempatam pelo `id`) | DC | Consumidor, diagnóstico | `event_date` | = |

Índice: `(collection_id, created_at)`, a leitura do histórico de uma coleta.

Catálogo dos eventos, fechado na A1.11 (`app/services/orchestration/events.py`, `EventName`): o DC só grava estes nomes, e o evento entra na mesma transação da mudança que ele registra.

| Nome | Autor | Quando | `metadata` |
|---|---|---|---|
| `collection.created` | `USER` | Pedido aceito | — |
| `collection.status_changed` | `SYSTEM` | A1.7 muda o status | `old`, `new` |
| `collection.cancelled` | `USER` | Cancelamento | — |
| `attempt.created` | `SYSTEM` | Nova tentativa (primeira ou retentativa) | `number`, `not_before`, `reason` (por que foi criada) |
| `attempt.dispatched` | `SYSTEM` | Fila confirmou a publicação | — |
| `attempt.job_created` | `SYSTEM` | Aviso `JOB_CREATED` do Launcher | `job_name` |
| `attempt.started` | `ROBOT` | `start` do worker | `job_name`, `pod_name`, `worker_version` |
| `attempt.finished` | `ROBOT` ou `SYSTEM` | `finish`, aviso do Launcher que encerra a tentativa, ou abandono | `status`, `error_code`, `recoverable`, `infra_event` |

Os itens não geram um evento por mudança: a linha do item é o estado, e o volume (centenas de itens por coleta) não compensa.

## De/para das tabelas do `public`

O `public` tem 19 tabelas do DC atual (mais a `alembic_version` dele), e o DC lê uma 20ª no banco do company-service. O v2 não lê nem escreve nenhuma do `public` (ADR-001).

| Tabela | O que é | No `agenor_coleta` |
|---|---|---|
| `collected` | A coleta | `collection`. `request_payload` vira as colunas de entrada; `response_payload` (o scraper gravava o retorno) sai, porque o resultado está nos itens e nas tentativas; `request_start_at`, `request_finished_at` e `finished_at` viram eventos; `path_s3` (ZIP) fica fora agora; `updated_at` sai |
| `collected_status_events` | Mudanças de status da coleta | `event` (`collection.status_changed`) |
| `collection_attempt` | Tentativas do orquestrador antigo (gravadas pelo shadow) | `attempt`, tabela própria (ADR-001). `strategy`, `mode` e `decision_log` eram do orquestrador antigo e não têm par; `next_attempt_at` → `not_before`; `queued_at` → `dispatched_at` |
| `collection_execution` | Um registro por documento ou competência, inserido de novo a cada execução | `item`, com chave idempotente. `report_type_id` → `report_type` em texto; `uri_files` → `file_key`; `tipo_versao_documento`, `identificador_arquivo` e `file_id` → `metadata`; `assessment_start_date` e `assessment_end_date` saem (vêm dos filtros); `invalid_at` sai (o item é atualizado no lugar) |
| `collection_execution_events` | Mudanças de status de cada execução | Sai: o item guarda o estado, sem histórico por item |
| `report_type` | Catálogo de documentos, com a URL da rota antiga por tipo | Sai: texto em `item.report_type` (decisão 5) |
| `ic_service_execution` | Auditoria das chamadas HTTP do coletor DARF ao Integra Contador, gravada pelo scraper em `POST /coleta-documentos/{id}/ic-executions` (rota, payloads, código de resposta, usuário). Não é uma execução de coleta | Sai. No 2.0 essas chamadas são do worker DARF e vão para os logs dele (ADR-008). Se o cliente precisar dessa auditoria guardada, decide-se ao portar o DARF (fase 4) |
| `darf_extract`, `gps_extract`, `dirf_extract`, `fontes_pagadoras_extract`, `dctf_extract_dec`, `dctf_extract_pdf`, `dctf_web_extract`, `credito_dctf_web`, `perdcomp_extract`, `document_data_perdcomp` | As 10 tabelas de extração do Agenor, uma ou duas por tipo, só inseridas | Saem: JSON no bucket, apontado por `item.extraction_key` (ADR-007). Tabelas e API de consulta são a fase 5 |
| `intimacao_extract`, `intimacao_extract_event` | Extração de intimações e o histórico dela | Saem: são do AGuiar, que fica no DC atual |
| `establishment` (banco do company-service) | Filiais e nomes de empresa, de outro banco | Continua lida pelo DC v2, só leitura (`app/models/establishment.py`, pedido 11). Não é do `agenor_coleta` e não muda. Serve ao nome da empresa e às filiais da A1.16 |

Contando a `intimacao_extract` com as 10 do Agenor, são 11 tabelas de extração; com a `intimacao_extract_event`, 12.

## Campos do contrato do front que o modelo não tem

Do `contrato/consumidor-dc-atual.openapi.json`. Nenhum vira coluna agora; a A1.16 decide cada um quando a API do consumidor for detalhada.

| Campo (resposta) | Situação |
|---|---|
| `request_payload` | Derivado: remontado das colunas de entrada (decisão 2) |
| `response_payload` | Fora agora: era o retorno bruto do scraper; no 2.0 não existe |
| `request_start_at`, `request_finished_at`, `finished_at` | Derivados dos eventos (`attempt.started` da primeira tentativa, `collection.status_changed` para o final) |
| `updated_at` | Fora agora (decisão 7) |
| `failure_reason` | Derivado: `status_text` |
| `assessment_start_date`, `assessment_end_date` | Derivados de `data_filters` |
| `document_summary` (contagem por status) e `dispatch_count` (itens concluídos) | Derivados: contagem de `item` por status |
| `company_name`, filiais (`/branches`, `branches_status`) | Derivados: `establishment` do company-service mais a contagem de coletas por CNPJ |
| `/empresas/stats` (total, concluídas, em andamento, com falha, pendentes) | Derivado: contagem de `collection` por status |
| `executions[]`: `report_type_name`, `competence`, `uri_files`, `error_message`, `status` | Derivados de `item` |
| `executions[]`: `tipo_versao_documento`, `identificador_arquivo` | Derivados de `item.metadata`, quando o DCTF for portado |
| `executions[]`: `request_start_at`, `request_finished_at`, `events` | Fora agora: não há histórico por item |
| `events[]` (`old_value`, `new_value`, `property_changed`, `property_reason`, `event_date`) | Derivados de `event` |
| `/download-disponivel` (`available`) e `/download-url` | Fora agora: dependem do ZIP (fase 4) |
| `message` do POST | Derivado: texto fixo da resposta |

Filtros da listagem: `client_document`, `power_of_attorney_document`, `request_user_id`, `status`, `collection_type` e `created_at` são colunas; `competence` e `report_type_name` vêm do `item`. Os índices dessas consultas entram com a A1.16.

## Mudanças em relação ao modelo da A1.3

| Tabela | Sai | Muda |
|---|---|---|
| `collection` | `request_payload`, `technical_failures`, `business_retries`, `zip_file_key`, `finished_at`, `updated_at`; os 3 índices de listagem | — |
| `attempt` | `attempt_type`, `job_created_at`, `job_name`, `pod_name`, `worker_version`, `started_at`, `finished_at`, `updated_at` | índices do despachante sem `attempt_type` |
| `item` | índice de `attempt_id` | — |
| `event` | índice de `attempt_id` | — |

Fora do banco: ADR-002 (o que vai para o evento, sem evento por item), ADR-004 (contagens derivadas das tentativas e a trava da coleta) e ADR-007 (o ZIP continua worker; a ligação com a coleta se decide na fase 4). Nenhuma mudança no `agenor-common`: a API e o evento da fila ficam como estão.

## Como mudar o modelo

1. Descreva a tabela, coluna ou índice aqui (para que serve, quem escreve, quem lê, o que substitui no `public`) e combine com o Lucas.
2. Mude o `app/models/agenor_coleta.py` e gere a revisão (skill `nova-migracao-agenor-coleta`).
3. O `revisor-isolamento-banco` confere se o modelo e este documento batem.
