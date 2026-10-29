---
name: nova-migracao-agenor-coleta
description: Cria uma migração Alembic nova no schema agenor_coleta do DC v2 (agenor-document-collector), mudando o modelo e a revisão juntos, com teste em Postgres e revisão de isolamento. Use ao adicionar ou mudar tabela, coluna, índice, constraint ou valor de status do DC v2.
---

# Nova migração no `agenor_coleta`

O DC v2 divide o Postgres com o DC atual e o AGuiar (ADR-001). Toda migração dele fica no schema `agenor_coleta`, com a `alembic_version` dentro dele, e roda numa etapa separada (`python -m app.migrate`), nunca no start do pod. Os passos abaixo saíram da primeira migração (A1.3) e da modelagem que a refez (A1.3b, `20261029_a057fe7dbe85_agenor_coleta_inicial.py`).

**O padrão é o autogenerate:** a regra vai no modelo, e a revisão é gerada a partir dele e revisada, com o mínimo de edição. Não escreva a revisão à mão. Na A1.3, a versão escrita à mão gerou nomes de CHECK duplicados no banco (`ck_collection_ck_collection_status`), porque a convenção de nomes era aplicada de novo sobre um nome já completo. A gerada usa `op.f(...)` e sai certa.

Tudo aqui é no `agenor-document-collector/`, exceto o passo 0.

## 0. Descreva no modelo de dados

Antes de tocar no código, a mudança entra no `docs/arquitetura/modelo-de-dados.md` da pasta de trabalho: para cada tabela, coluna ou índice, para que serve, quem escreve, quem lê e o que substitui no `public`. Combine com o Lucas antes de seguir.

- Só entra o que um fluxo definido hoje escreve **e** lê. O contrato do front de hoje é referência, não requisito.
- Estado que um fluxo consulta é coluna; quando e onde algo aconteceu (Job, pod, versão, horários) vai para o `event`.
- Uma coluna que sai também sai do documento (ou fica riscada, com o motivo).

A A1.3 pulou esta etapa e a A1.3b teve de refazer o modelo e a migração.

## 1. Mude o modelo

Em `app/models/agenor_coleta.py`. Os modelos herdam de `V2Base`, cujo `MetaData` já tem `schema="agenor_coleta"` e a convenção de nomes (`ix_`, `uq_`, `ck_`, `fk_`, `pk_`): não passe `schema=` nem nome de constraint à mão, salvo em índice com expressão (`text(...)`), que precisa de nome explícito.

- **Status e tipos:** coluna `mapped_column(_status(MeuEnum))` (texto convertido para o enum no Python) mais `_check_in("coluna", MeuEnum)` no `__table_args__`. O CHECK é constraint da tabela, com nome `ck_<tabela>_<coluna>` pela convenção, e o autogenerate o gera com esse nome. Nunca tipo `ENUM` do Postgres nem `create_constraint=True` no `Enum`.
- **Coluna nova em tabela com dados:** `nullable=True` ou `server_default`. Uma coluna `NOT NULL` sem padrão falha na tabela já populada.
- **FK:** só para tabela do `agenor_coleta`. Nunca para o `public`.

## 2. Gere a revisão num banco descartável

Com o `local/` no ar (`local/up.sh`):

```bash
docker compose -f ../local/compose.yaml exec -T db psql -U agenor -d document_collector \
  -c "DROP DATABASE IF EXISTS agenor_coleta_autogen" -c "CREATE DATABASE agenor_coleta_autogen"
POSTGRES_USER=agenor POSTGRES_PASSWORD=agenor-local POSTGRES_SERVER=127.0.0.1 POSTGRES_PORT=5428 \
  POSTGRES_DB=agenor_coleta_autogen uv run python -m app.migrate        # sobe até a head atual
uv run python - <<'EOF'
from alembic import command
from app.migrate import alembic_config
config = alembic_config("postgresql+asyncpg://agenor:agenor-local@127.0.0.1:5428/agenor_coleta_autogen")
command.revision(config, message="<o que muda, curto>", autogenerate=True)
EOF
docker compose -f ../local/compose.yaml exec -T db psql -U agenor -d document_collector -c "DROP DATABASE agenor_coleta_autogen"
```

O identificador e o nome do arquivo também são do Alembic: não passe `rev_id` nem renomeie o arquivo. O `file_template` do `alembic.ini` gera `AAAAMMDD_<rev>_<slug da mensagem>.py`, com a data na frente para as revisões ficarem em ordem na pasta. Por isso a mensagem é curta e diz o assunto (vira o slug); a atividade e os detalhes vão no docstring.

## 3. Revise a revisão gerada

Mantenha o que o autogenerate escreveu e confira:

- `schema="agenor_coleta"` em toda operação e nomes de constraint com `op.f(...)` (já vêm assim, formatados pelo `ruff`);
- os valores de `CHECK` estão escritos na revisão (o autogenerate os escreve literalmente; não troque por import do código);
- `downgrade()` desfaz só o que a revisão fez. O schema e a `alembic_version` nunca saem;
- nada de `CREATE SCHEMA` (o `env.py` cuida disso).

### Quando o autogenerate não detecta algo

Escrever à mão é o último recurso. Antes:

1. **Analise por que ele não detectou.** Em geral, é a regra que não está no modelo, ou que está de um jeito que ele não lê (como o CHECK dentro do tipo `Enum`, na A1.3), ou é uma comparação desligada no `env.py`.
2. **Tente fazer com que ele detecte.** Ponha a regra no modelo (constraint, índice, `server_default`), ligue a comparação no `env.py` (`compare_server_default`, por exemplo) ou registre um comparador (`alembic.autogenerate.comparators`). Se resolver, gere de novo e não escreva nada à mão.
3. **Só se não houver como**, escreva à mão, e registre o motivo no docstring da revisão.

Casos conhecidos em que não há como:

- **troca de valores de um CHECK:** o Alembic não compara CHECK;
- **renomear coluna ou tabela:** ele vê um drop e um add, e perderia os dados;
- **migração de dados.**

**O que se escreve à mão fica como se tivesse sido gerado:** as mesmas chamadas `op.*`, os mesmos argumentos, `schema="agenor_coleta"` e nomes com `op.f("...")`, dentro do bloco `# ### commands auto generated by Alembic ###`. Para saber a forma exata, gere uma revisão de teste que faça a mesma operação e copie o estilo. A formatação é a do `ruff`: o `alembic.ini` roda `ruff check --fix` e `ruff format` em toda revisão gerada (`post_write_hooks`), e o hook do Claude Code faz o mesmo nas edições. Exemplo, para a troca de valores de um CHECK:

```python
op.drop_constraint(op.f("ck_attempt_status"), "attempt", schema="agenor_coleta", type_="check")
op.create_check_constraint(op.f("ck_attempt_status"), "attempt", "status IN ('QUEUED', ...)", schema="agenor_coleta")
```

Em migração de dados, use `op.execute` com `agenor_coleta.` no nome da tabela.

No docstring, uma linha dizendo a atividade e, se houver, o que foi escrito à mão e por quê. A `20261029_a057fe7dbe85_agenor_coleta_inicial.py` é o exemplo de revisão gerada.

## 4. Teste

```bash
uv run python -m app.migrate --sql | grep -n "public"     # não pode aparecer nada
scripts/agent/verify.sh                                    # inclui os testes em Postgres
```

O `tests/test_migrations_agenor_coleta.py` já confere, num banco descartável: que só o `agenor_coleta` muda, que o downgrade e o upgrade voltam ao mesmo lugar, que o `public` do DC atual fica intacto, que modelo e migração estão em sincronia (`test_models_match_migrations`) e que os nomes e os valores dos CHECKs no banco são os do modelo (`test_constraint_names_follow_model_convention` e `test_check_values_match_model`, que cobrem o que o autogenerate não compara). Um valor novo num enum sem a migração que troca o CHECK falha neste último. Se a mudança cria regra no banco (constraint, índice único), acrescente um caso em `tests/test_models_agenor_coleta.py`.

Para conferir no banco local do DC atual:

```bash
POSTGRES_USER=agenor POSTGRES_PASSWORD=agenor-local POSTGRES_SERVER=127.0.0.1 POSTGRES_PORT=5428 \
  POSTGRES_DB=document_collector uv run python -m app.migrate
docker compose -f ../local/compose.yaml restart dc-atual   # o DC atual precisa voltar com health 200
../local/check.sh
```

## 5. Revisão de isolamento e commit

Antes de mostrar os commits ao Lucas, rode o subagente `revisor-isolamento-banco` sobre `alembic/` e `app/models/`. Ele confere também se o modelo bate com o `modelo-de-dados.md` (passo 0). Os commits só entram com a confirmação dele (`AGENTS.md` da raiz).
