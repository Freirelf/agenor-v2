# ADR-004: A tabela de tentativas é a fila de verdade, e o DC decide capacidade e retentativa

- **Status:** Aceito
- **Data:** 2026-10-27
- **Origem:** plano, §3.0, §3.2 ("Configuração da fila") e §3.4 ("Retentativa", "Despachante", "Limites iniciais", "Abandono", "Duas contagens"); padrão do ADR-002 do Agnes Collector

## Contexto

- Sem sessão e-CAC, o scraper apaga a mensagem e nada reenfileira: a retentativa não tem dono.
- O `dispatch_due_attempts` do DC atual é um stub.
- Gravar no banco e publicar na fila são duas operações separadas. Se uma acontecer e a outra não, a coleta não pode se perder.
- Uma mensagem publicada na OCI Queue não pode ser reordenada nem retirada.
- A API de mensagens da OCI não lê a DLQ (só contagem e limpeza).
- Hoje o paralelismo é de 6 coletas (uma por réplica do scraper), e Créditos DCTFWeb depende do Moon, com até 4 sessões.

## Decisão

### Despachante

A **tabela de tentativas é a fila de verdade**; a OCI Queue só transporta o que pode rodar agora. Para cada tipo, o despachante:

1. pega um lock no banco;
2. calcula as vagas: limite do tipo menos as tentativas despachadas e não concluídas, respeitando também o limite total;
3. escolhe as próximas tentativas prontas (hora de retentativa já chegou), em ordem de criação;
4. publica na fila e, **só depois que a fila confirma**, marca a tentativa como despachada (`dispatched_at`).

Roda **por evento** (coleta criada, tentativa encerrada) e numa **varredura a cada 1 min**, que republica o que falhou ao publicar, libera as retentativas cuja hora chegou e detecta abandono. Existe um único processo de varredura.

**Limites iniciais:** 6 no total, igual a hoje. Créditos DCTFWeb no máximo 4 (Moon). Os limites ficam em configuração e sobem conforme medirmos o Agnaldo e os proxies. Não há limite por procurador: o Agnaldo reserva sessões de forma atômica, e quem não consegue cai em `NO_SESSION`.

O Launcher não decide concorrência: só mantém um teto de segurança do cluster ([ADR-005](adr-005-launcher-com-kubernetes-jobs.md)).

### Retentativa

Duas contagens separadas, por coleta:

| Contagem | Resultados que contam | Política |
|---|---|---|
| **Falha técnica** | `INFRA_FAILED`, `TIMED_OUT`, abandono | Nova tentativa logo em seguida; na 3ª falha técnica, a coleta vai para `FAILED` |
| **Retentativa de negócio** | `NO_SESSION`, `FAILED` recuperável | Nova tentativa depois de 5, 15, 30, 60 e 60 min, e depois a cada 60 min, até o limite do tipo; então `FAILED` com o motivo |

- `NO_SESSION` deixa a coleta em `WAITING_SESSION` enquanto espera.
- `FAILED` não recuperável (ex.: procuração inválida) leva a coleta a `FAILED` imediatamente.
- `CANCELLED` não conta em nenhuma das duas.
- A espera é gravada como hora de retentativa na nova tentativa; o despachante só a publica quando a hora chega.

### Abandono

Detectado pelo banco na varredura, como no Agnes Collector:

- o worker começou e está **sem sinal de vida há mais de 5 min**; ou
- **nenhum worker começou** a tentativa em 60 min depois de despachada (≈ 3 entregas de 15 min, quando a OCI move a mensagem para a DLQ).

Nos dois casos a tentativa termina em `INFRA_FAILED`, conta uma falha técnica e a coleta ganha uma nova tentativa. A mensagem antiga, se voltar, é descartada como obsoleta ([ADR-002](adr-002-tentativa-e-status.md)). O Launcher também informa as falhas de Job que vê; o que chegar primeiro encerra a tentativa, e o segundo aviso é ignorado.

### Fila

Uma fila por ambiente, nova para o 2.0: visibilidade de 15 min, retenção de 7 dias, no máximo 3 entregas, depois DLQ. A DLQ vira só descarte de mensagens obsoletas.

O DC v2 e o Launcher falam com a fila pela interface `agenor_common.queue.Queue` (publicar, receber, renovar, apagar), com um adaptador local para desenvolvimento e testes e um da OCI Queue para os ambientes (A1.17).

### Sem Temporal nesta fase

O Agnes Collector usa Temporal para horários e agendamentos recorrentes. O Agenor não tem agendamento recorrente agora, e a varredura de 1 min resolve as esperas de retentativa. Precisão de até 1 min é suficiente para esperas de 5 a 60 min.

## Alternativas consideradas

- **Publicar tudo direto na fila.** Perde ordem e capacidade, e a retentativa volta a depender da fila.
- **Retentativa pela fila** (visibilidade ou reentrega). A fila não sabe por que a tentativa falhou nem quanto esperar.
- **Concorrência no Launcher, com canais por tipo.** Foi a primeira versão (26/10). Mudou para o DC na §3.12: o DC já tem o estado, e uma fila só basta.
- **Tratar abandono pela DLQ.** A API da OCI não lê a DLQ.
- **Tabela outbox separada.** A tabela de tentativas já cumpre esse papel.

## Consequências

- O despachante é o ponto mais delicado do DC v2 (A1.8) e precisa de testes com concorrência real no Postgres.
- Os 8 cenários do M1 (A2.10) exercitam publicação, reentrega, abandono, retentativa e cancelamento no ambiente local.
- Os limites são calibrados com as métricas do próprio 2.0, primeiro local e depois em STG.
