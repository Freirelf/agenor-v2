# ADR-002: A tentativa é a unidade de execução, e o DC é o único dono do status

- **Status:** Aceito
- **Data:** 2026-10-27
- **Origem:** plano, §3.0, §3.1 e §3.4 ("Único dono do status" e "Histórico de eventos")

## Contexto

No DC atual:

- o **status da coleta tem vários escritores**: o scraper grava direto, e o DC também recalcula;
- os callbacks não têm identificador de execução, então uma execução antiga pode sobrescrever o resultado de uma nova;
- as extrações e os itens são só inseridos, e uma nova execução duplica linhas;
- a proteção contra execução duplicada depende de um lock no Redis do scraper.

No 2.0, uma coleta pode rodar mais de uma vez (retentativa, falha de pod, reentrega da fila). É preciso saber qual execução vale e quem decide o status.

## Decisão

### Tentativa

Cada vez que o DC manda executar uma coleta, ele cria uma **tentativa** (tabela própria no `agenor_v2`, [ADR-001](adr-001-isolamento-no-schema-agenor-v2.md)).

- Uma coleta tem uma ou mais tentativas, **no máximo uma ativa por vez**.
- O `attempt_id` acompanha a mensagem, o Job, os logs e cada chamada do worker. É ele que liga solicitação → mensagem → Job → execução.
- O worker só age se a tentativa ainda for a vigente. Qualquer chamada de uma tentativa que não vale mais é recusada.

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

- `QUEUED`: criada, aguardando o despachante ou já na fila. A publicação é registrada em `dispatched_at`, não no status.
- `STARTING`: o Launcher avisou que criou o Job.
- `RUNNING`: o worker chamou `start`.

### Sinal de vida e cancelamento

O worker avisa o DC ao começar e **a cada 1 min**. A resposta diz se a tentativa ainda vale. Se não vale (coleta cancelada ou tentativa substituída), o worker para entre um item e outro, devolve a sessão e a tentativa termina em `CANCELLED`. É o protocolo do `dispatch_id` do Agnes Collector.

### Itens

O worker registra cada item (documento ou competência) com uma **chave idempotente** dentro da coleta. Registrar o mesmo item de novo atualiza, não duplica. Antes de coletar, o worker consulta os itens já concluídos da coleta e pula esses, para retomar sem baixar de novo.

### Status da coleta

O worker **nunca grava o status da coleta**. Ele informa itens e o resultado da tentativa, e o DC calcula o status a partir disso. É o único escritor.

Os valores do status da coleta continuam os de hoje, para não quebrar quem consulta: `PENDING`, `PROCESSING`, `WAITING_SESSION`, `FINISHED`, `PARTIALLY_FINISHED`, `FINISHED_EMPTY`, `FAILED` e `FILE_NOT_FOUND` (este último está no código da staging, embora o plano não o listasse). A regra exata do cálculo (itens × resultado da tentativa → status) é fechada na A1.7 e registrada aqui.

### Histórico de eventos

No formato do Agnes Collector, numa tabela do `agenor_v2`:

- categoria;
- nome com ponto (`collection.dispatched`, `attempt.no_session`, `item.downloaded`);
- mensagem;
- autor (`ROBOT`, `USER` ou `SYSTEM`);
- metadados.

A coleta ganha também um `status_text` legível. As tabelas de eventos do `public` continuam para o AGuiar.

## Alternativas consideradas

- **Reaproveitar a `collection_attempt`.** Já é gravada pelo orquestrador antigo ([ADR-001](adr-001-isolamento-no-schema-agenor-v2.md)).
- **O worker grava o status da coleta, como hoje.** Mantém os vários escritores e as corridas entre execuções.
- **Lock no Redis contra execução duplicada.** Desnecessário com uma tentativa ativa por coleta e a recusa das chamadas de tentativas obsoletas. Os workers deixam de depender de Redis.

## Consequências

- Entregas repetidas da fila e Jobs duplicados ficam inofensivos: só a tentativa vigente age.
- O DC concentra a regra de status, que precisa de testes cobrindo cada combinação de itens e resultado.
- Cancelar uma coleta não mata o Job: o worker para no próximo sinal de vida, em até 1 min mais o tempo do item em andamento.
- Os status novos de tentativa não aparecem na API do consumidor, que continua expondo só os status da coleta.
