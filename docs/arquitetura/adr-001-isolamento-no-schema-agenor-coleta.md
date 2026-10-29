# ADR-001: O DC v2 fica isolado no schema `agenor_coleta`

- **Status:** Aceito
- **Data:** 2026-10-27
- **Origem:** plano, §3.0, §3.4 ("Duas releases, um banco" e "Migrações do v2") e §3.13, itens 1 a 8
- **Atualizado:** 2026-10-29 (A1.3b): o schema passou de `agenor_v2` para `agenor_coleta`. Um "v2" no nome ficaria para sempre depois da virada; `agenor_coleta` diz que o schema é da coleta do Agenor feita por nós. A troca foi antes de qualquer ambiente: a migração só tinha sido aplicada no banco local

## Contexto

O DC v2 nasce do DC atual e precisa usar o mesmo Postgres de PRD (`hiperautomacao_document_collector_prd`). Nesse banco já escrevem:

- o **DC atual**, que atende o AGuiar, o scraper e a API antiga;
- a release **`-apisix`** do DC, com código de 30/07 e o sweeper do orquestrador em modo ativo.

O que o código atual mostra:

1. O AGuiar e o Agenor usam as mesmas tabelas (`collected`, `collection_execution`, eventos), diferenciados só pelo `collection_type`.
2. Os status são `Enum` no código antigo (`collection_models.py:89,123`). Um valor novo numa linha que ele lê quebra telas e rotas.
3. Uma coluna nova `NOT NULL` sem valor padrão faz falhar os inserts do código antigo.
4. Os sweepers antigos (`find_stuck_collected_ids`) olham todas as execuções paradas e, na `-apisix`, republicam a coleta na fila antiga.
5. A `collection_attempt` já recebe gravações do orquestrador antigo (o shadow registra tentativas a cada 2 h).
6. O DC atual roda `alembic upgrade head` toda vez que o pod sobe (`entrypoint.sh`). Se a `alembic_version` do `public` tiver uma revisão que ele não conhece, ele não sobe mais, e o AGuiar cai junto.

## Decisão

**Duas releases, um banco, dois schemas.**

- O DC v2 roda em **release própria**, ao lado do DC atual, que não recebe código novo.
- Tudo o que é do v2 fica no schema **`agenor_coleta`**: coleta, tentativa, itens, histórico de eventos.
- O v2 **não cria, não altera e não grava** nada no `public`. Leitura do `public` também não faz parte do desenho.
- A tabela de tentativas é **própria** do v2. A `collection_attempt` não é reaproveitada.
- Os status novos (`CANCELLED`, `NO_SESSION`, `INFRA_FAILED`, `TIMED_OUT`) existem só no `agenor_coleta`.

**Migrações:**

- Alembic, com a tabela de versão **dentro do schema** (`agenor_coleta.alembic_version`, via `version_table_schema`).
- Aplicadas numa **etapa separada, antes do deploy**: a imagem do DC v2 tem um comando só de migração, rodado como Job. No v2, o Alembic sai do entrypoint do pod.
- Como essa etapa roda nos ambientes (por exemplo, um Job de hook do Helm `pre-install,pre-upgrade`, como no Agnes Collector) é decisão do cliente, dono do deploy (pedido 10). No ambiente local, ela roda como um Job no kind, a partir de manifestos em `local/`.
- O schema é criado pelo `env.py`, antes da `alembic_version` (que mora nele), e só se ainda não existir: se o schema for criado antes por um DBA, o usuário do v2 não precisa de `CREATE` no banco. Nenhuma migração do v2 usa nome de tabela sem schema.
- O `env.py` segura uma trava de sessão (`pg_try_advisory_lock` de duas chaves, até 5 min) contra dois Jobs de migração ao mesmo tempo, e o autogenerate só enxerga o `agenor_coleta`.
- Comando: `python -m app.migrate` (só as variáveis `POSTGRES_*`); `--sql` imprime o SQL sem conectar.
- Status são texto com `CHECK` nomeado na tabela, não tipo `ENUM` do Postgres: nada é criado fora do schema, e um valor novo é uma migração simples.
- As revisões são geradas pelo autogenerate a partir dos modelos e revisadas. Quando ele não detecta algo, primeiro se analisa por quê e se tenta fazer com que detecte. Só o que ele não tem como detectar (troca de valores de `CHECK`, renomeação, dados) é escrito à mão, no mesmo formato da revisão gerada. Um teste confere que os nomes das constraints no banco são os do modelo.

**Verificado no ambiente local (A1.3, 28/10):** com o banco do DC atual, o `public` ficou idêntico antes e depois da migração do v2 (versão do Alembic, tabelas, colunas e constraints), e o DC atual reiniciou e respondeu 200. Os testes repetem isso num banco descartável (`tests/test_migrations_agenor_coleta.py`).

**Banco do company-service:** o acesso continua (GPS por filial e nomes de empresa dependem dele), com usuário somente leitura e credencial em Secret (pedido 11 ao cliente).

## Por que resolve cada ponto

| Ponto do código atual | Como fica |
|---|---|
| Tabelas compartilhadas com o AGuiar | O v2 não toca nelas |
| Status como `Enum` no código antigo | Os status novos não chegam ao `public` |
| Coluna nova obrigatória | Nenhuma coluna é adicionada ao `public` |
| Sweepers antigos olhando todas as execuções | O código antigo consulta só o `public` e não enxerga as coletas do v2 |
| `collection_attempt` em uso | Tabela de tentativas própria |
| `alembic upgrade head` no start do DC atual | A `alembic_version` do `public` não recebe revisões do v2 |
| Listagens antigas (`/coleta-documentos`, `/extracoes`, `consult_*`) | Não mostram coletas do v2; elas são consultadas pela API do v2 |

## Alternativas consideradas

- **Colunas novas nas tabelas do `public`, com uma chave de ambiente.** Exigiria mexer no DC atual e manter compatibilidade com o código antigo e a `-apisix`. Descartada no refinamento de 26/10.
- **Tabelas novas no `public` com `alembic_version_v2`.** Foi a primeira versão (26/10). Resolve o Alembic, mas mistura as tabelas dos dois sistemas e não dá um limite claro para tirar o v2 depois. Substituída pelo schema em 27/10.
- **Banco próprio para o v2.** Exige infra nova do cliente agora. O schema deixa essa porta aberta: `pg_dump -n agenor_coleta`.

## Consequências

- O DC atual precisa subir, reiniciar e funcionar com o schema `agenor_coleta` presente. Isso é verificado no ambiente local (A1.15); a `-apisix`, em STG (A6.4).
- O v2 precisa de permissão para criar o schema na primeira migração, ou de o schema já existir com o dono certo.
- O DC v2 nasce sem as rotas antigas sobre o `public`, sem `consult_*`, `/extracoes` e `query_consult`, e sem o orquestrador, os sweepers e o consumo da fila antiga (A1.13).
- Mudanças em `alembic/`, `app/models/` e `app/repositories/` do DC v2 passam pelo subagente `revisor-isolamento-banco` antes do commit.
- O sweeper ativo da `-apisix` não enxerga o v2, mas continua sendo alerta ao cliente (pedido 14).
