# Padrões de código

- **Status:** aprovado pelo Lucas em 29/10. Vale para os quatro repositórios de código: `agenor-document-collector`, `agenor-launcher`, `agenor-workers` e `agenor-common`.
- **Por quê:** até aqui o código seguia em parte a estrutura herdada do DC atual e em parte decisões de cada sessão. Já apareciam nomes misturados (`repositories/coleta.py` ao lado de `establishment_repository.py`), duas formas de abrir sessão no banco e segredos em `str` (um erro de validação do pydantic imprimiu valores do `.env`). Este documento fixa um padrão só, simples, e diz como o código herdado chega nele.

## Princípios

Os padrões de projeto (GoF), os arquiteturais e o SOLID, com onde cada um está no código, ficam em [padroes-de-projeto.md](padroes-de-projeto.md).


1. **O mais simples que resolve o que a arquitetura pede agora.** Abstração só no segundo uso real, não no primeiro imaginado. Nada de arquitetura hexagonal, DDD com agregados, repositório genérico com classe base, contêiner de injeção de dependência ou unit of work próprio.
2. **Explícito.** Funções com nome que diz o que fazem, tipos em toda assinatura, erros com código. Sem mágica de import, sem estado global além da configuração.
3. **Cada coisa num lugar.** Uma regra mora numa camada só; a camada é fácil de achar pelo nome da pasta.
4. **Testado.** Todo comportamento novo tem teste; todo bug corrigido ganha o teste que o pegaria.

## Estrutura de cada repositório

Organização **por camada**, o padrão mais usado em serviços FastAPI e o que o DC já tem. Para o tamanho do projeto (quatro tabelas, duas APIs, um tipo de worker por pacote), separar por domínio só acrescentaria pastas.

### DC (`agenor-document-collector`)

```text
app/
  main.py            monta o app: rotas, middlewares, observabilidade
  config.py          Settings (pydantic-settings), o único lugar que lê o ambiente
  auth.py            autenticação dos serviços (ADR-006)
  routers/           HTTP: uma rota por arquivo de assunto (v2/attempts.py, health.py)
  services/          regra de negócio e transação, um pacote por assunto (orchestration/)
  repositories/      consultas e travas, um módulo por entidade (collection.py, establishment.py)
  models/            tabelas SQLAlchemy, um módulo por schema (agenor_coleta.py) e o banco do company-service
  schemas/           modelos pydantic de entrada e saída que não são contrato compartilhado
  clients/           clientes de serviços externos (storage, fila)
  utils/             funções puras, sem I/O e sem camada (validação de CNPJ)
tests/               espelha app/: test_<camada>_<módulo>.py; factories.py com os dados de teste
scripts/             ferramentas de linha de comando (export_openapi_v2.py), também com nomes em inglês
```

### Launcher (`agenor-launcher`)

Mesma ideia, sem banco: `app/main.py`, `app/config.py`, `app/services/` (consumo da fila, criação e observação dos Jobs), `app/clients/` (Kubernetes, DC), `app/catalog.py` (catálogo de tipos).

### Workers (`agenor-workers`)

- `core/`: o fluxo comum (ADR-007): `config.py`, `runner.py` (o ciclo da tentativa), `clients/` (DC, Agnaldo, bucket), `errors.py` (erros tipados).
- `workers/<tipo>/`: só o que é do tipo: `planner.py` (itens), `collector.py` (coleta de um item), `parser.py` (extração), `__main__.py` (entrypoint `python -m workers.<tipo>`).

### Contratos (`agenor-common`)

Biblioteca: `api.py`, `events.py`, `queue*.py`. Só modelos, interfaces e adaptadores; nenhuma regra de negócio, nenhum acesso a banco além do adaptador de fila local.

## Camadas

A dependência anda num sentido só: **rota → serviço → repositório → modelo**. Uma camada não importa a de cima.

| Camada | Faz | Não faz |
|---|---|---|
| **Rota** (`routers/`) | Recebe e valida (modelos do `agenor_common` ou de `schemas/`), autentica por `Depends`, chama **um** serviço e traduz o erro de domínio para `{code, message}` | SQL, regra de negócio, abrir transação |
| **Serviço** (`services/`) | A regra de negócio. Um caso de uso é uma função e uma transação (`async with session.begin()`). Decide o que travar e quando confirmar. Levanta exceções de domínio | Saber de HTTP (`HTTPException`, `Request`, status code) |
| **Repositório** (`repositories/`) | Consultas e travas, em funções que recebem a `AsyncSession`. A ordem das travas fica escrita no módulo | Regra de negócio, `commit` |
| **Modelo** (`models/`, `schemas/`) | Estrutura: tabelas SQLAlchemy e modelos pydantic | Lógica além de validação de formato |
| **Cliente** (`clients/`) | Falar com um serviço externo (fila, bucket, Agnaldo, Kubernetes, DC), com timeout e retentativa (`tenacity`) | Regra de negócio |

- **Funções, não classes,** nos serviços e repositórios. Classe só quando houver estado de verdade (um cliente com conexão, por exemplo).
- **Gravações simples** (`session.add`) podem ficar no serviço; o repositório guarda o que é consulta ou trava.

## Banco e transação

- **Uma sessão por requisição**, pela dependência `get_session`. Ela não confirma nada: quem confirma é o serviço, com `async with session.begin()`.
- **Uma transação por caso de uso.** O evento do histórico entra na mesma transação da mudança que ele registra.
- **Travas sempre na mesma ordem:** a coleta antes da tentativa (`lock_collection`, `lock_attempt`). Quem trava uma tentativa entra pelo repositório, nunca com um `SELECT … FOR UPDATE` solto.
- **Toda mudança de tabela ou coluna** passa antes pelo [modelo de dados](modelo-de-dados.md) e pela skill `nova-migracao-agenor-coleta`.

## Erros

- **Exceção de domínio com código.** Cada serviço tem as suas, herdando de uma base com `code` (ex.: `AttemptError` com `ATTEMPT_NOT_CURRENT`). A rota traduz para `ErrorResponse` (`{code, message}`, ADR-003).
- **`raise … from err`** ao trocar uma exceção por outra; nunca `except:` nem `except Exception` sem relançar ou registrar com o motivo.
- **Falha cedo:** configuração inválida derruba o processo na subida, não na primeira requisição.

## Contratos e validação

- O que atravessa serviços (API do worker e do Launcher, evento da fila) mora no `agenor-common`, com `extra="forbid"` e `frozen=True`. Mudança nele é uma tag nova (ADR-003).
- Modelos pydantic de entrada sempre validam: nada de `dict` solto chegando no serviço.
- `Any` só para JSON livre de verdade (`data_filters`, `metadata`) e para objeto de biblioteca sem tipos (o cliente da OCI).

## Configuração e segredos

- **Um `Settings` por serviço** (`pydantic-settings`), em `config.py`, validado na subida. Nenhum outro arquivo lê `os.environ`.
- **Segredo é `SecretStr`** (senha, chave, token) e o `Settings` usa `hide_input_in_errors=True`: um erro de validação não imprime o valor. Toda variável fica documentada no `.env.example`, sem valor real.
- Nada de URL de produção ou credencial no código, nos values ou nos commits.

## Nomes

- **Identificadores em inglês; comentários, docstrings e documentos em português.** Os termos do domínio têm tradução fixa:

  | Domínio | Código |
  |---|---|
  | coleta | `collection` (`collected_id` no contrato herdado) |
  | tentativa | `attempt` |
  | item | `item` |
  | evento / histórico | `event` |
  | procurador | `power_of_attorney` |
  | despachante | `dispatcher` |
  | varredura | `sweep` |
  | retentativa | `retry` |
  | sinal de vida | `heartbeat` |

- **Módulos com o nome da entidade ou do assunto, sem sufixo:** a pasta já diz a camada (`repositories/collection.py`, não `collection_repository.py`).
- Funções com verbo (`lock_collection`, `record_event`); booleanos com `is_`/`has_`; constantes em `MAIÚSCULAS`; enums `StrEnum`.

## Tipos

- Anotação em toda função e atributo, no estilo novo (`X | None`, `list[str]`).
- **`mypy` no `verify.sh`** de cada repositório, com o plugin do pydantic. O código herdado que ainda não passa fica numa lista de exceções no `pyproject.toml`, com o motivo, e sai dela quando for tocado.

## Assíncrono

- **DC e Launcher são assíncronos:** todo I/O com `await`. Chamada bloqueante (SDK síncrono, por exemplo) vai para `asyncio.to_thread`.
- **Workers podem ser síncronos:** eles executam uma tentativa por processo, e o código portado do scraper é síncrono. O sinal de vida roda em thread.

## Logs

- `logging` da biblioteca padrão: `logger = logging.getLogger(__name__)` em cada módulo. A saída em JSON, com `attempt_id` e `collected_id` no contexto, é configurada uma vez na subida (A1.14, ADR-008). O `loguru` herdado sai quando cada arquivo for tocado.
- Nunca logar segredo, token, CPF ou CNPJ completo sem necessidade.

## Comentários e docstrings

- **Docstring de módulo** diz o que ele faz e a decisão que segue (ADR, atividade). Docstring de função só quando o nome e os tipos não bastam.
- Comentário explica **por quê**, não o quê. Nada de código comentado.

## Testes

- `pytest` com `pytest-asyncio`. Arquivo `tests/test_<camada>_<módulo>.py`; teste com nome do comportamento (`test_finish_repeated_returns_same_state`).
- **Banco de verdade:** serviço e repositório rodam contra o Postgres do `local/`, num banco descartável. Sem mock de SQLAlchemy.
- **Fakes, não mocks, para o que é nosso:** a fila em memória, um DC falso para o worker. Mock só na borda externa (HTTP do Agnaldo, Kubernetes).
- Concorrência que importa (travas, despachante) tem teste com duas sessões de verdade.

## Ferramentas

| Ferramenta | Regra |
|---|---|
| `ruff format` | Formatação, `line-length = 120` |
| `ruff check` | Regras `E`, `W`, `F`, `I`, `B`, `UP`, `SIM`, `RUF`, `PT`, `ASYNC`, `C4`. Exceções por arquivo, com o motivo |
| `mypy` | Tipos, com o plugin do pydantic |
| `pytest` | Testes, com cobertura no relatório |
| `scripts/agent/verify.sh` | Roda tudo acima; nada vai para commit com ele vermelho |

## Código herdado

O DC trouxe código do DC atual (schemas do consumidor, storage, middleware do Ledger, `domains/billing`, `utils/`). Ele **entra no padrão quando for tocado**, na atividade que o usa (A1.14 para observabilidade, A1.16 para a API do consumidor), sem refatoração em massa. Até lá, as exceções ficam listadas no `pyproject.toml`, cada uma com o motivo.
