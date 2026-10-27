# ADR-003: Contratos entre os serviços

- **Status:** Aceito
- **Data:** 2026-10-27
- **Origem:** plano, §3.2 e §3.4 ("Muda no DC v2"), e §3.13, item 17

## Contexto

Hoje a mensagem da fila leva a entrada completa da coleta (CNPJs, procurador, filtros), os callbacks do scraper ao DC não têm autenticação nem identificador de execução, e o scraper grava o status direto.

No 2.0 há quatro fronteiras: consumidor → DC, DC → fila → Launcher, Launcher → Job do worker, e worker/Launcher → DC. Os repositórios são separados; o que é compartilhado (evento da fila, modelos da API, interface de fila) fica no `agenor-common`, instalado por tag Git.

## Decisão

### 1. Evento da fila (DC → fila → Launcher)

```json
{ "version": 1, "type": "DARF", "collected_id": "…", "attempt_id": "…", "dispatched_at": "…" }
```

- **Só identificadores.** CNPJs, procurador e filtros não trafegam na fila. Mesmo formato do evento do Agnes Collector.
- Versionado (`version`). Uma mudança incompatível sobe a versão, e o Launcher recusa versões que não conhece.
- Modelo: `agenor_common.events.DispatchEvent` (`extra="forbid"`).
- **Só vai para a fila o que pode rodar agora** ([ADR-004](adr-004-despachante-e-retentativa.md)). Por isso há uma fila só, sem canal por tipo.

### 2. Entrada do Job (Launcher → worker)

- O Launcher cria o Job com `ATTEMPT_ID`, `COLLECTED_ID` e `COLLECTION_TYPE` como variáveis de ambiente, mais a configuração do tipo.
- Ao subir, o worker **busca a entrada completa no DC** pelo `attempt_id`: cliente, procurador, filtros e `force`. Dados fiscais e pessoais não ficam na definição do Job.
- Se a tentativa não for mais a vigente, o DC devolve vazio e o worker encerra sem fazer nada.

### 3. API do worker no DC

Nova, versionada e só para o Agenor 2.0.

| Chamada | Para quê |
|---|---|
| `GET /attempts/{id}/input` | Ler a entrada; vazio se a tentativa não for a vigente |
| `POST /attempts/{id}/start` | Marcar o início (`RUNNING`) |
| `PUT /attempts/{id}/heartbeat` | Sinal de vida a cada 1 min; responde `{active}` |
| `PUT /attempts/{id}/items` | Registrar ou atualizar itens em lote, com chave idempotente |
| `GET /collections/{id}/done-items` | Itens já concluídos da coleta, para retomar |
| `POST /attempts/{id}/finish` | Resultado final, com erro tipado e se é recuperável |

### 4. API do Launcher no DC

| Chamada | Para quê |
|---|---|
| `POST /attempts/{id}/infra-event` | Job criado; Job terminou (sucesso, falha, prazo estourado, falta de memória, imagem inexistente) |

### 5. API do consumidor no DC

Solicitar a coleta, consultar o status, listar e baixar, **com o mesmo contrato de solicitação e consulta que o DC atual expõe ao Agenor**, sobre o `agenor_v2`. É o que torna a virada uma troca de rota ([ADR-009](adr-009-virada-unica-pelos-consumidores.md)). O mapeamento exato das rotas atuais é feito na A1.16.

### Regras comuns

- Toda chamada é autenticada ([ADR-006](adr-006-autenticacao-por-usuario-de-servico-do-agnaldo.md)). Não existem o header de bypass nem a identificação só por `X-User-ID`.
- Toda chamada do worker e do Launcher é idempotente: repetir não muda o resultado.
- O contrato é escrito em OpenAPI (A1.1) antes da implementação, e os modelos ficam no `agenor-common`.

## Alternativas consideradas

- **Entrada completa na mensagem.** Coloca dados fiscais na fila e na definição do pod, e a mensagem pode ficar obsoleta enquanto espera.
- **O worker consome a fila.** Foi o que um dos documentos do cliente sugeriu. Não daria ao Launcher o controle do ciclo de vida do pod.
- **Contrato novo também para o consumidor.** Obrigaria o front e os outros consumidores a mudar junto com a virada.

## Consequências

- O worker depende do DC no ar para começar. Se o DC estiver fora, a tentativa é recuperada pela detecção de abandono.
- Uma mudança de contrato é uma nova tag do `agenor-common` e uma atualização em cada repositório que o usa.
- A rota dos consumidores passa pelo Agnaldo/APISIX, que não é nosso: a troca de rota é pedida ao cliente (A6.9).
