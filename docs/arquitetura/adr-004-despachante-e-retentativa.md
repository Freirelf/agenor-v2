# ADR-004: A tabela de tentativas é a fila de verdade, e o DC decide capacidade e retentativa

- **Status:** Aceito
- **Data:** 2026-10-27
- **Origem:** plano, §3.0, §3.2 ("Configuração da fila") e §3.4 ("Retentativa", "Despachante", "Limites iniciais", "Abandono", "Duas contagens"); padrão do ADR-002 do Agnes Collector
- **Atualizado:** 2026-10-29 (A1.3b): as contagens saem das tentativas, sem contador na coleta; o tipo do despachante é o da coleta. 2026-10-29 (A1.9): limite da retentativa de negócio por janela de tempo. 2026-10-29 (A1.8): como o despachante roda (trava bloqueante, laço na API, pelo menos uma vez)

## Contexto

- Sem sessão e-CAC, o scraper apaga a mensagem e nada reenfileira: a retentativa não tem dono.
- O `dispatch_due_attempts` do DC atual é um stub.
- Gravar no banco e publicar na fila são duas operações separadas. Se uma acontecer e a outra não, a coleta não pode se perder.
- Uma mensagem publicada na OCI Queue não pode ser reordenada nem retirada.
- A API de mensagens da OCI não lê a DLQ (só contagem e limpeza).
- Hoje o paralelismo é de 6 coletas (uma por réplica do scraper), e Créditos DCTFWeb depende do Moon, com até 4 sessões.

## Decisão

### Despachante

A **tabela de tentativas é a fila de verdade**; a OCI Queue só transporta o que pode rodar agora. Para cada tipo de coleta (o tipo da tentativa é o da coleta), o despachante:

1. pega um lock no banco;
2. calcula as vagas: limite do tipo menos as tentativas despachadas e não concluídas, respeitando também o limite total;
3. escolhe as próximas tentativas prontas (hora de retentativa já chegou), em ordem de criação;
4. publica na fila e, **só depois que a fila confirma**, marca a tentativa como despachada (`dispatched_at`).

Roda **por evento** (coleta criada, tentativa encerrada) e numa **varredura a cada 1 min**, que republica o que falhou ao publicar, libera as retentativas cuja hora chegou e detecta abandono. A varredura roda em cada réplica da API, mas uma de cada vez (trava no banco).

**Como roda (A1.8, 29/10):**

- **Dentro do processo da API** (decisão 3 da #341): cada réplica tem uma tarefa que roda o despachante a cada `DISPATCH_SWEEP_SECONDS` (60) ou quando é acordada depois da transação que criou a coleta ou encerrou a tentativa. Pedidos que chegam durante uma rodada se juntam na seguinte. Sem Deployment novo.
- **Trava bloqueante no despacho** (`pg_advisory_xact_lock`, com `lock_timeout`), não `try` (decisão do Lucas, 29/10): com o `try`, a réplica que perde a trava desistiria, e a que está despachando pode ter contado as vagas antes do fim que liberou uma; a vaga ou a coleta nova esperaria até 1 min. O despacho é curto e cada réplica espera no máximo uma rodada. A parte de abandono da varredura (A1.10) usa `pg_try_advisory_xact_lock`, com chave própria (as chaves são `(0x41474E32, n)`: 1 das migrações, 2 do despacho, 3 reservada ao abandono): basta uma réplica por vez.
- **Uma transação por rodada:** vagas (tentativas com `dispatched_at` e não encerradas, por tipo da coleta), prontas (`QUEUED`, sem `dispatched_at`, `not_before` vencido, coleta não cancelada) em ordem de criação, e uma publicação por vez. Só depois da confirmação da fila a tentativa ganha `dispatched_at` e o evento `attempt.dispatched`. Se a fila falha ou não responde em 10 s, a rodada para e confirma as já publicadas; as outras ficam para a próxima. As publicações da rodada inteira cabem em 20 s, abaixo do `lock_timeout` (30 s, que vale só para pegar a trava), para uma fila lenta não segurar a trava das outras réplicas; a rodada que não pega a trava no `lock_timeout` desiste com aviso, e a próxima tenta de novo.
- **Pelo menos uma vez:** se a transação não confirmar depois da publicação, a tentativa sai de novo na rodada seguinte. A mensagem repetida é inofensiva: o Launcher deduplica pelo nome do Job ([ADR-005](adr-005-launcher-com-kubernetes-jobs.md)), e só a tentativa vigente age.
- O despacho atualiza a tentativa sem travar a coleta, e só se ela ainda estiver `QUEUED` e sem publicação (as prontas são lidas sem trava; a que terminou durante a publicação não ganha `dispatched_at` nem evento). Ele pode esperar uma transição (a linha da tentativa) ou um lote de itens, mas nenhum deles espera algo que ele segure: na coleta, ele só pede a `KEY SHARE` da FK do evento, compatível com o `FOR NO KEY UPDATE`. Sem ciclo, sem deadlock, enquanto cada transação de transição tocar uma coleta só (o abandono incluído).
- Limites em registro por tipo (`dispatch_limits()` em `dispatcher.py` do DC, Strategy): `DISPATCH_MAX_IN_FLIGHT` e `DISPATCH_MAX_IN_FLIGHT_BY_TYPE` ([infra.md](infra.md)).

**Limites iniciais:** 6 no total, igual a hoje. Créditos DCTFWeb no máximo 4 (Moon). Os limites ficam em configuração e sobem conforme medirmos o Agnaldo e os proxies. Não há limite por procurador: o Agnaldo reserva sessões de forma atômica, e quem não consegue cai em `NO_SESSION`.

O Launcher não decide concorrência: só mantém um teto de segurança do cluster ([ADR-005](adr-005-launcher-com-kubernetes-jobs.md)).

### Retentativa

Duas contagens separadas, por coleta:

| Contagem | Resultados que contam | Política |
|---|---|---|
| **Falha técnica** | `INFRA_FAILED`, `TIMED_OUT`, abandono | Nova tentativa logo em seguida; na 3ª falha técnica, a coleta vai para `FAILED` (ou `PARTIALLY_FINISHED`, se algum item tem arquivo: ADR-002) |
| **Retentativa de negócio** | `NO_SESSION`, `FAILED` recuperável | Nova tentativa depois de 5, 15, 30, 60 e 60 min, e depois a cada 60 min, enquanto a primeira falha de negócio da coleta tiver menos de 8 h (janela); então `FAILED` com o motivo |

- `NO_SESSION` deixa a coleta em `WAITING_SESSION` enquanto espera.
- `FAILED` não recuperável (ex.: procuração inválida) leva a coleta a `FAILED` imediatamente.
- `CANCELLED` não conta em nenhuma das duas.
- As contagens não são gravadas: saem das tentativas da coleta no momento em que uma termina (por status e `recoverable`), com a linha da coleta travada (`SELECT … FOR NO KEY UPDATE`, que não bloqueia quem só insere itens ou eventos da coleta). É a mesma trava que serializa o fim da tentativa, o aviso do Launcher e o abandono da mesma coleta, então não há contador para ficar fora de sincronia. A espera da retentativa de negócio sai do número de retentativas de negócio já feitas.
- A espera é gravada como hora de retentativa na nova tentativa; o despachante só a publica quando a hora chega.
- **Limite da retentativa de negócio por tempo, não por contagem (29/10, A1.9).** O que importa para quem pediu é quanto tempo o sistema insiste antes de dar a resposta definitiva; uma contagem depende da tabela de esperas e não diz isso. A janela é `RETRY_BUSINESS_WINDOW_HOURS` (padrão 8 h, para a resposta sair no mesmo dia), contada da primeira falha de negócio da coleta, e sai das tentativas, como as contagens. Uma nova tentativa só é criada se a hora dela (`not_before`) cair dentro da janela. O 8 h é inicial: é calibrado em STG com as métricas da A1.14 (A6.4). Substitui o "10 retentativas" da decisão 2 da #341, que não tinha base em dados.
- A política fica num registro por tipo (`retry_policies()` em `retry.py` do DC, Strategy). Hoje todos os tipos usam a mesma; um tipo que precise de outra janela vira uma entrada nova.
- A falha técnica continua por contagem (3): a nova tentativa é imediata, e o limite evita insistir num Job que não sobe.
- Coleta cancelada não ganha retentativa, qualquer que seja o resultado.
- O limite só funciona se só falha passageira chegar a ele: causa permanente (certificado vencido, sem procuração) é `FAILED` não recuperável, nunca `NO_SESSION` ([ADR-007](adr-007-workers-por-tipo-com-base-comum.md), A3.5).

### Abandono

Detectado pelo banco na varredura, como no Agnes Collector:

- o worker começou e está **sem sinal de vida há mais de 5 min**; ou
- **nenhum worker começou** a tentativa em 60 min depois de despachada (≈ 3 entregas de 15 min, quando a OCI move a mensagem para a DLQ).

Nos dois casos a tentativa termina em `INFRA_FAILED`, conta uma falha técnica e a coleta ganha uma nova tentativa. A mensagem antiga, se voltar, é descartada como obsoleta ([ADR-002](adr-002-tentativa-e-status.md)). O Launcher também informa as falhas de Job que vê; o que chegar primeiro encerra a tentativa, e o segundo aviso é ignorado.

### Fila

Uma fila por ambiente, nova para o 2.0: visibilidade de 15 min, retenção de 7 dias, no máximo 3 entregas, depois DLQ. A DLQ vira só descarte de mensagens obsoletas.

O DC v2 e o Launcher falam com a fila pela interface assíncrona `agenor_common.queue.Queue` (publicar, receber, renovar, apagar), escolhida por `QUEUE_PROVIDER` (A1.17, 28/10):

- **local:** uma tabela no schema `fila_local` do Postgres do ambiente local (`queue_postgres.py`). Atravessa processos (DC no compose, Launcher no kind) e reproduz a OCI: visibilidade, recibo novo a cada entrega, reentrega e DLQ depois de 3 entregas. O DC recusa esse provedor fora do ambiente local.
- **oci:** a OCI Queue pelo SDK (`queue_oci.py`), autenticada pelo `config` do SDK em arquivo. Testado com o cliente simulado; validado em DEV (A6.3).
- **em memória:** só para testes.

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
