# ADR-002: A tentativa é a unidade de execução, e o DC é o único dono do status

- **Status:** Aceito
- **Data:** 2026-10-27
- **Origem:** plano, §3.0, §3.1 e §3.4 ("Único dono do status" e "Histórico de eventos")
- **Atualizado:** 2026-10-29 (A1.3b): o que fica na tentativa e o que vai para o histórico, pelo [modelo de dados](modelo-de-dados.md)

## Contexto

No DC atual:

- o **status da coleta tem vários escritores**: o scraper grava direto, e o DC também recalcula;
- os callbacks não têm identificador de execução, então uma execução antiga pode sobrescrever o resultado de uma nova;
- as extrações e os itens são só inseridos, e uma nova execução duplica linhas;
- a proteção contra execução duplicada depende de um lock no Redis do scraper.

No 2.0, uma coleta pode rodar mais de uma vez (retentativa, falha de pod, reentrega da fila). É preciso saber qual execução vale e quem decide o status.

## Decisão

### Tentativa

Cada vez que o DC manda executar uma coleta, ele cria uma **tentativa** (tabela própria no `agenor_coleta`, [ADR-001](adr-001-isolamento-no-schema-agenor-coleta.md)).

- Uma coleta tem uma ou mais tentativas, **no máximo uma ativa por vez**.
- O `attempt_id` acompanha a mensagem, o Job, os logs e cada chamada do worker. É ele que liga solicitação → mensagem → Job → execução.
- O worker só age se a tentativa ainda for a vigente. Qualquer chamada de uma tentativa que não vale mais é recusada.
- A tentativa guarda só o estado que o despachante, o abandono e a retentativa consultam: status, hora de retentativa, publicação, último sinal de vida e o erro. Job, pod, versão do worker e os horários de criação do Job, início e fim vão para o histórico de eventos. O tipo é o da coleta. O detalhe de cada coluna está no [modelo de dados](modelo-de-dados.md).

Status da tentativa:

```text
QUEUED → STARTING → RUNNING → um final
```

| Status final | Quando |
|---|---|
| `SUCCEEDED` | O worker terminou com sucesso |
| `FAILED` | O worker terminou com erro tipado, com o motivo e se é recuperável |
| `NO_SESSION` | Não havia sessão e-CAC disponível no Agnaldo |
| `INFRA_FAILED` | O Job não subiu, caiu, ficou sem memória ou a imagem não existe; ou a tentativa foi abandonada ([ADR-004](adr-004-despachante-e-retentativa.md)) |
| `TIMED_OUT` | O Job estourou o tempo máximo do tipo |
| `CANCELLED` | A coleta foi cancelada ou a tentativa foi substituída. Não conta como falha técnica nem como retentativa |

Atalhos permitidos, além do ciclo linear (tabela em `app/services/orchestration/states.py` do DC, com teste de cada transição; atualizado em 29/10):

- `QUEUED → RUNNING`: o `start` do worker pode chegar antes do aviso `JOB_CREATED` do Launcher.
- `QUEUED` ou `STARTING` → qualquer final: o Launcher (Job que falhou), o abandono e o cancelamento encerram a tentativa em qualquer ponto. O `finish` do worker só vale depois do `start`, salvo o `CANCELLED` de uma coleta cancelada (A1.6).
- De um status final não se sai: um aviso atrasado não reabre a tentativa.

- `QUEUED`: criada, aguardando o despachante ou já na fila. A publicação é registrada em `dispatched_at`, não no status.
- `STARTING`: o Launcher avisou que criou o Job.
- `RUNNING`: o worker chamou `start`.

### Sinal de vida e cancelamento

O worker avisa o DC ao começar e **a cada 1 min**. A resposta diz se a tentativa ainda vale. Se não vale (coleta cancelada ou tentativa substituída), o worker para entre um item e outro, devolve a sessão e a tentativa termina em `CANCELLED`. É o protocolo do `dispatch_id` do Agnes Collector.

### Itens

O worker registra cada item (documento ou competência) com uma **chave idempotente** dentro da coleta. Registrar o mesmo item de novo atualiza, não duplica. Antes de coletar, o worker consulta os itens já concluídos da coleta e pula esses, para retomar sem baixar de novo.

### Status da coleta

O worker **nunca grava o status da coleta**. Ele informa itens e o resultado da tentativa, e o DC calcula o status a partir disso. É o único escritor.

Os valores do status da coleta continuam os de hoje, para não quebrar quem consulta: `PENDING`, `PROCESSING`, `WAITING_SESSION`, `FINISHED`, `PARTIALLY_FINISHED`, `FINISHED_EMPTY`, `FAILED` e `FILE_NOT_FOUND` (este último está no código da staging, embora o plano não o listasse). A regra do cálculo foi fechada na A1.7 (29/10), num ponto só (`app/services/orchestration/collection_status.py` do DC), a partir das duas últimas tentativas e da contagem dos itens:

| Última tentativa | Status da coleta |
|---|---|
| `QUEUED`, número 1 | `PENDING` (o Job ainda não foi criado) |
| `QUEUED`, retentativa depois de `NO_SESSION` | `WAITING_SESSION` |
| `QUEUED`, outra retentativa (técnica ou `FAILED` recuperável) | `PROCESSING` |
| `STARTING` ou `RUNNING` | `PROCESSING` |
| `SUCCEEDED` | pelos itens: nenhum `FAILED` e algum `FINISHED` (com arquivo) → `FINISHED`; nenhum `FAILED` e nenhum com arquivo, ou sem itens → `FINISHED_EMPTY`; `FAILED` com outros → `PARTIALLY_FINISHED`; todos `FAILED` → `FAILED` |
| outro final, sem nova tentativa (falha não recuperável, retentativas esgotadas, cancelamento) | `PARTIALLY_FINISHED` se algum item tem arquivo; senão `FAILED` |

- O `status_text` diz o motivo (o erro da tentativa, "Coleta cancelada" ou a espera de sessão) e a contagem dos itens.
- Coleta cancelada cujo worker terminou com `SUCCEEDED` (ele só para entre um item e outro) fica pelo resultado dos itens: o que foi coletado vale. "Coleta cancelada" aparece só quando a tentativa termina em `CANCELLED`.
- `SUCCEEDED` com itens `FAILED` não gera retentativa: ela depende só do resultado da tentativa ([ADR-004](adr-004-despachante-e-retentativa.md)).
- O cálculo não conhece a política de retentativa: a nova tentativa é criada antes (A1.9) e passa a ser a última.
- Transições da coleta numa tabela (`COLLECTION_TRANSITIONS` em `states.py`): `PENDING → PROCESSING ⇄ WAITING_SESSION`, e de qualquer um desses para um final. Um status final não se reabre: coletar de novo é uma coleta nova. `FILE_NOT_FOUND` não é produzido (a regra do DC atual também nunca o produzia).
- Cada mudança grava o evento `collection.status_changed` (`old`, `new`).

### Histórico de eventos

No formato do Agnes Collector, numa tabela do `agenor_coleta`:

- categoria;
- nome com ponto (`collection.status_changed`, `attempt.started`, `attempt.finished`);
- mensagem;
- autor (`ROBOT`, `USER` ou `SYSTEM`);
- metadados.

Não há evento por item: a linha do item é o estado dele, e o volume (centenas de itens por coleta) não compensa. O catálogo dos nomes fecha na A1.11.

A coleta ganha também um `status_text` legível. As tabelas de eventos do `public` continuam para o AGuiar.

## Alternativas consideradas

- **Reaproveitar a `collection_attempt`.** Já é gravada pelo orquestrador antigo ([ADR-001](adr-001-isolamento-no-schema-agenor-coleta.md)).
- **O worker grava o status da coleta, como hoje.** Mantém os vários escritores e as corridas entre execuções.
- **Lock no Redis contra execução duplicada.** Desnecessário com uma tentativa ativa por coleta e a recusa das chamadas de tentativas obsoletas. Os workers deixam de depender de Redis.

## Consequências

- Entregas repetidas da fila e Jobs duplicados ficam inofensivos: só a tentativa vigente age.
- O DC concentra a regra de status, que precisa de testes cobrindo cada combinação de itens e resultado.
- Cancelar uma coleta não mata o Job: o worker para no próximo sinal de vida, em até 1 min mais o tempo do item em andamento.
- Os status novos de tentativa não aparecem na API do consumidor, que continua expondo só os status da coleta.
