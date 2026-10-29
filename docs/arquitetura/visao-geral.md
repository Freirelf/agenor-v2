# Visão geral da arquitetura

O retrato do Agenor 2.0 como ele é hoje: as peças, o caminho de uma coleta, onde fica cada coisa e qual documento manda em cada assunto. O porquê de cada decisão está nos ADRs; o detalhe, nos documentos que esta página aponta.

## As peças

```text
 consumidor (front do Agenor e outros, pelo Agnaldo/APISIX)
      │  API do consumidor (/api/v1, mesmo contrato do DC atual)
      ▼
 ┌──────────────── Document Collector v2 (DC) ────────────────┐
 │ registra a coleta · cria as tentativas · despacha · decide  │◀── Postgres, schema agenor_coleta
 │ status, retentativa e abandono · guarda o histórico         │    (o public é do DC atual)
 └──────┬───────────────────────────────────────────▲─────────┘
        │ evento só com ids                          │ API do worker e do Launcher (/api/v2)
        ▼                                            │
      fila (OCI Queue; no local, tabela fila_local)  │
        │                                            │
        ▼                                            │
    Launcher ── cria e acompanha ──▶ Job do worker ───┘
    (sem banco)    um por tentativa   um tipo por worker
                                         │        │
                                     Agnaldo    bucket
                                  (sessão e-CAC) (arquivos e JSON da extração)
```

| Peça | Repositório | Faz | Não faz |
|---|---|---|---|
| **DC v2** | `agenor-document-collector` | Recebe a coleta, cria as tentativas, despacha o que pode rodar, recebe o que o worker e o Launcher informam e calcula o status. Único escritor do banco | Coletar; criar pods |
| **Launcher** | `agenor-launcher` | Consome a fila, cria um Kubernetes Job por tentativa e informa ao DC como cada Job terminou | Decidir concorrência ou retentativa; ter banco |
| **Workers** | `agenor-workers` | `core/`: o fluxo comum (entrada, sinal de vida, sessão no Agnaldo, itens, fim). `workers/<tipo>/`: planejar, coletar e extrair o que é do tipo | Gravar status; consumir a fila |
| **Contratos** | `agenor-common` | Modelos da API do worker e do Launcher, evento da fila e interface de fila com os adaptadores (memória, local, OCI). Biblioteca, instalada por tag Git | Regra de negócio |

Fora daqui, usados e não alterados: o Agnaldo (sessões e-CAC e autenticação dos serviços), o banco do company-service (filiais, só leitura), o bucket e a infra do cliente (cluster, fila, pipelines).

## Uma coleta, de ponta a ponta

1. **Pedido.** O consumidor pede a coleta. O DC grava a `collection` e a primeira `attempt` (`QUEUED`), na mesma transação, com os eventos.
2. **Despacho.** O despachante do DC calcula as vagas por tipo (limites em configuração), publica na fila só o que pode rodar agora e, depois que a fila confirma, grava `dispatched_at`. Uma varredura a cada 1 min republica o que falhou, libera retentativas e detecta abandono.
3. **Job.** O Launcher consome o evento, cria o Job com nome determinístico e avisa o DC (`JOB_CREATED` → `STARTING`). Só então apaga a mensagem.
4. **Execução.** O worker busca a entrada no DC pelo `attempt_id` (`input`), marca o início (`start` → `RUNNING`), manda sinal de vida a cada 1 min (`heartbeat`, que diz se ainda vale), informa os itens com chave idempotente (`items`) e o resultado (`finish`).
5. **Status.** O DC, e só ele, calcula o status da coleta a partir dos itens e do resultado da tentativa.
6. **Se der errado.** Falha do worker (`FAILED`, `NO_SESSION`), do Job (avisada pelo Launcher) ou abandono (detectado pela varredura) encerram a tentativa. O DC decide se cria outra (falha técnica até 3; retentativa de negócio com espera crescente) ou encerra a coleta.

Entregas repetidas da fila e Jobs duplicados são inofensivos: só a tentativa vigente age, e toda chamada é idempotente.

## Onde está cada assunto

| Assunto | Documento |
|---|---|
| Isolamento no banco e migrações | [ADR-001](adr-001-isolamento-no-schema-agenor-coleta.md) |
| Tentativa, status e histórico | [ADR-002](adr-002-tentativa-e-status.md) |
| Contratos (fila, API do worker, do Launcher e do consumidor) | [ADR-003](adr-003-contratos.md) e o `agenor_common.api` |
| Despachante, retentativa, abandono e fila | [ADR-004](adr-004-despachante-e-retentativa.md) |
| Launcher e Jobs | [ADR-005](adr-005-launcher-com-kubernetes-jobs.md) |
| Autenticação entre serviços | [ADR-006](adr-006-autenticacao-por-usuario-de-servico-do-agnaldo.md) |
| Workers, base comum, bucket e ZIP | [ADR-007](adr-007-workers-por-tipo-com-base-comum.md) |
| Observabilidade | [ADR-008](adr-008-observabilidade.md) |
| Virada para produção | [ADR-009](adr-009-virada-unica-pelos-consumidores.md) |
| Tabelas e colunas do `agenor_coleta` | [modelo-de-dados.md](modelo-de-dados.md) |
| Como o código de cada serviço se organiza | [padroes-de-codigo.md](padroes-de-codigo.md) |
| Padrões arquiteturais, GoF e SOLID | [padroes-de-projeto.md](padroes-de-projeto.md) |
| Como trabalhamos (atividade, commit, revisão, documentação) | [padroes-de-desenvolvimento.md](../padroes-de-desenvolvimento.md) |
| O que o código precisa do ambiente | [infra.md](infra.md) |
| Ambiente local | `local/README.md` |
| Plano, status e próximas atividades | [PLANO_AGENOR_2_0.md](../PLANO_AGENOR_2_0.md) |
