# Padrões de projeto, padrões arquiteturais e SOLID

- **Status:** aprovado pelo Lucas em 29/10, e o código existente foi adequado no mesmo dia.
- **O que é:** a base de construção do Agenor 2.0. Para cada problema que aparece ao construir o sistema, o padrão que usamos e a forma dele no projeto. Vale para os quatro repositórios de código e completa os [padrões de código](padroes-de-codigo.md) (camadas, nomes, tipos, testes).

## Como usar

1. Antes de escrever algo novo, procure o problema na [tabela de decisão](#tabela-de-decisão). Se ele estiver lá, use o padrão indicado, na forma descrita aqui.
2. O docstring do módulo ou da classe diz o padrão que ele implementa ("Adapter da OCI Queue para o `Queue`").
3. Um problema que não está na tabela entra aqui, com o padrão escolhido, antes do código.
4. Em Python, cada padrão tem a forma mais direta: `Protocol` para interface, função para comportamento sem estado, `dataclass` ou modelo pydantic para dados, `StrEnum` para o que tem valores fechados. Classe com herança só quando o padrão pede estado compartilhado de verdade.

## Tabela de decisão

| Preciso… | Padrão | Seção |
|---|---|---|
| falar com um sistema externo (fila, bucket, Agnaldo, Kubernetes, DC, portal) | **Adapter** atrás de um `Protocol` | [Adapter](#adapter) |
| escolher a implementação pela configuração | **Factory Method** | [Factory Method](#factory-method) |
| um recurso único por processo (configuração, engine, cliente) | **Singleton** de módulo | [Singleton](#singleton) |
| expor um caso de uso para a rota, o worker ou a varredura | **Facade** (função de serviço) | [Facade](#facade) |
| ler ou travar dados no banco | **Repository** | [Repository](#repository) |
| um comportamento que muda por tipo de coleta ou por configuração | **Strategy** em registro por enum | [Strategy](#strategy) |
| um fluxo fixo com passos que cada tipo implementa | **Template Method** | [Template Method](#template-method) |
| uma entidade com ciclo de vida (status) | **State** como tabela de transições | [State](#state) |
| mandar outro serviço executar algo | **Command** (mensagem versionada) | [Command](#command) |
| reagir a eventos de fora (Jobs do Kubernetes, fila) | **Observer** com tabela de tratadores | [Observer](#observer) |
| retentativa, cache, métrica ou autenticação em volta de uma chamada | **Decorator** | [Decorator](#decorator) |
| etapas comuns a toda requisição | **Chain of Responsibility** (middleware e dependências) | [Chain of Responsibility](#chain-of-responsibility) |
| dados de teste | **Factory de teste** | [Factory de teste](#factory-de-teste) |

## 1. Padrões arquiteturais

Regras de como as peças se dividem e conversam. Os ADRs têm o porquê de cada uma.

1. **Orquestração centralizada.** O DC decide o que roda, quando, quantas vezes e o status. Launcher e workers executam e informam; nunca decidem nem falam entre si (ADR-002, ADR-004).
2. **Um dono por dado.** Só o DC grava no banco. Os outros serviços leem e informam pela API do DC (ADR-001, ADR-003).
3. **Camadas dentro de cada serviço:** rota → serviço → repositório → modelo, com `clients/` para o que é externo. A dependência anda num sentido só ([padrões de código](padroes-de-codigo.md)).
4. **Banco como fila de verdade.** O que precisa rodar fica numa tabela; um publicador (o despachante) leva à fila só o que pode rodar agora e marca a publicação depois que a fila confirma (ADR-004).
5. **Mensagem com identificadores** (*claim check*). A fila leva só ids e versão; quem recebe busca o resto no dono do dado (ADR-003).
6. **Um processo efêmero por tarefa.** Cada tentativa roda num Job próprio, que termina com ela (ADR-005).
7. **Idempotência em toda fronteira.** Toda chamada entre serviços pode ser repetida sem mudar o resultado: chave idempotente, "só a tentativa vigente age", criação com nome determinístico (ADR-002, ADR-003, ADR-005).
8. **Sinal de vida com prazo.** Todo trabalho longo avisa que está vivo; o dono detecta o abandono pelo banco (ADR-002, ADR-004).
9. **Retentativa com espera crescente**, decidida pelo dono do estado e separada por tipo de falha (técnica e de negócio) (ADR-004).
10. **Contrato publicado.** O que atravessa serviços mora no `agenor-common`, versionado; nenhum serviço redefine um contrato (ADR-003).
11. **Isolamento no banco compartilhado.** Tudo do Agenor 2.0 no schema `agenor_coleta` (ADR-001).

## 2. Padrões de projeto (GoF e afins)

### Criacionais

#### Factory Method

**Quando:** a implementação concreta depende da configuração (provedor de fila, cliente do bucket, cliente do Kubernetes real ou local).

**Forma:** uma função `create_<coisa>(config) -> <Protocol>`, num lugar só, com `match` no enum da configuração. Quem usa recebe o `Protocol` e não conhece a classe concreta. Import da implementação dentro do ramo, quando ela exige dependência opcional.

```python
def create_queue(config: QueueConfig) -> Queue:
    match config.provider:
        case QueueProvider.LOCAL:
            from agenor_common.queue_postgres import PostgresQueue
            return PostgresQueue(dsn=_required(config, "local_dsn"), queue_name=config.local_queue_name)
        case QueueProvider.OCI:
            ...
```

**Referência:** `agenor_common/queue.py` (`create_queue`).

#### Singleton

**Quando:** um recurso deve existir uma vez por processo: configuração, engine do banco, cliente HTTP com pool, cliente da fila.

**Forma:** objeto de módulo (`settings = Settings()`) para o que é barato e sempre necessário; função com `@functools.cache` (`get_engine()`) para o que é caro ou depende da configuração, criado na primeira chamada. Nunca uma classe que controla a própria instância. Nunca estado global mutável de negócio. O teste limpa o cache (`get_engine.cache_clear()`) quando precisa.

**Referência:** `app/config.py` (`settings`), `app/database.py` (`get_engine`, `get_session_factory`).

### Estruturais

#### Adapter

**Quando:** toda integração com algo de fora: fila, bucket, Agnaldo, Kubernetes, a API do DC (vista pelo worker e pelo Launcher), portais da Receita.

**Forma:**

- um `Protocol` com o que **quem usa** precisa, no lado de quem usa (ou no `agenor-common`, se for compartilhado);
- uma classe em `clients/` (ou no adaptador do `agenor-common`) que implementa o `Protocol` com a biblioteca externa;
- os tipos e os erros da biblioteca não saem do adaptador: viram os nossos (`QueueError`, por exemplo);
- timeout e retentativa ficam no adaptador ([Decorator](#decorator));
- um adaptador em memória para os testes, que passa na mesma suíte de comportamento.

```python
class Queue(Protocol):
    async def publish(self, body: str) -> None: ...
    async def receive(self, max_messages: int, wait_seconds: int, ...) -> list[ReceivedMessage]: ...


class OciQueue:  # Adapter da OCI Queue para o Queue
    async def publish(self, body: str) -> None:
        try:
            await asyncio.to_thread(self._client.put_messages, ...)
        except oci.exceptions.ServiceError as err:
            raise QueueError(str(err)) from err
```

**Referência:** `agenor_common/queue*.py`, `app/auth.py` (`SigningKeyProvider`, `JwksKeyProvider`).

#### Facade

**Quando:** expor um caso de uso para quem chama (rota, varredura, worker).

**Forma:** uma função de serviço por caso de uso (`attempts.finish`, `dispatcher.dispatch`), que abre a transação, trava, chama repositórios, grava o evento e devolve o resultado. Quem chama faz uma chamada só e não conhece travas, repositório nem eventos. No worker, o `core` é a fachada do Agnaldo, do DC e do bucket para o código do tipo.

**Referência:** `app/services/orchestration/attempts.py`.

#### Repository

**Quando:** toda leitura e trava no banco.

**Forma:** funções em `repositories/<entidade>.py` que recebem a `AsyncSession` e devolvem modelos. Sem `commit` (a transação é do serviço). A ordem das travas fica escrita no docstring do módulo. A sessão do SQLAlchemy é a unidade de trabalho: não criamos outra.

**Referência:** `app/repositories/collection.py`.

#### Decorator

**Quando:** comportamento transversal em volta de uma chamada: retentativa, cache, métrica, autenticação.

**Forma:** decorador do Python ou dependência do FastAPI: `tenacity.retry` nos adaptadores, `functools.cache` nos recursos, `Depends(require_worker)` nas rotas. O decorador não contém regra de negócio.

```python
@retry(stop=stop_after_attempt(3), wait=wait_exponential(max=10), retry=retry_if_exception_type(QueueError))
async def publish(self, body: str) -> None: ...
```

**Referência:** `app/auth.py` (`require_worker`, `require_launcher`), `app/database.py` (`@cache`).

### Comportamentais

#### Strategy

**Quando:** um comportamento muda por tipo de coleta ou por configuração: política de retentativa, limites do despachante, o worker de cada tipo, a imagem e os recursos de cada tipo no Launcher.

**Forma:** um `Protocol` (ou um `dataclass` de parâmetros, quando a variação é só de valores) e um **registro** `dict[Enum, Estratégia]`. O código pega a estratégia pelo enum; **nunca** `if tipo == ...` espalhado. Um tipo novo é uma entrada nova no registro.

```python
@dataclass(frozen=True)
class RetryPolicy:
    max_technical_failures: int
    business_waits: tuple[timedelta, ...]
    max_business_retries: int


RETRY_POLICIES: dict[CollectionType, RetryPolicy] = {...}  # montado da configuração


def retry_policy(collection_type: CollectionType) -> RetryPolicy:
    return RETRY_POLICIES[collection_type]
```

**Referência:** `QUEUE_PROVIDER` + `create_queue`; a política de retentativa entra assim na A1.9 e o catálogo de tipos do Launcher na fase 2.

#### Template Method

**Quando:** um fluxo fixo com passos que variam: o ciclo da tentativa no worker (entrada → início → sessão → itens → fim, ADR-007).

**Forma:** o `core` tem a função que conduz o fluxo (`run_attempt`) e recebe um objeto que implementa um `Protocol` só com os passos variáveis. O worker do tipo implementa esses passos e mais nada; sessão, sinal de vida, cancelamento, bucket e erros são do `core`.

```python
class Collector(Protocol):
    def plan(self, attempt: AttemptInputData) -> list[PlannedItem]: ...
    def collect(self, session: AgnaldoSession, item: PlannedItem) -> CollectedFile: ...
    def parse(self, item: PlannedItem, file: CollectedFile) -> dict[str, Any]: ...


def run_attempt(collector: Collector, settings: WorkerSettings) -> None:
    """O fluxo comum (ADR-007). O worker do tipo só implementa o Collector."""
```

**Referência:** entra na fase 3 (`agenor-workers/core/runner.py`), com o piloto Fontes Pagadoras.

#### State

**Quando:** uma entidade com ciclo de vida: a tentativa (`QUEUED → STARTING → RUNNING → final`, ADR-002), a coleta (os status de hoje).

**Forma:** uma **tabela de transições** permitidas e uma função que valida a mudança, no serviço dono da entidade. Toda mudança de status passa por ela; nenhum `attempt.status = ...` fora dela. A tabela tem teste com cada transição permitida e proibida.

```python
ATTEMPT_TRANSITIONS: dict[AttemptStatus, frozenset[AttemptStatus]] = {
    AttemptStatus.QUEUED: frozenset({AttemptStatus.STARTING, AttemptStatus.RUNNING, *FINAL_STATUSES}),
    AttemptStatus.STARTING: frozenset({AttemptStatus.RUNNING, *FINAL_STATUSES}),
    AttemptStatus.RUNNING: FINAL_STATUSES,
}


def transition(attempt: Attempt, new_status: AttemptStatus) -> None:
    if new_status not in ATTEMPT_TRANSITIONS.get(attempt.status, frozenset()):
        raise AttemptNotCurrentError(attempt.id, f"{attempt.status.value} → {new_status.value} não é permitida")
    attempt.status = new_status
```

**Referência:** `app/services/orchestration/states.py` (`ATTEMPT_TRANSITIONS`, `transition_attempt`), com o teste de cada transição em `tests/test_services_orchestration_states.py`. A da coleta (`COLLECTION_TRANSITIONS`, `transition_collection`) entrou na A1.7, no mesmo módulo e no mesmo teste.

#### Command

**Quando:** um serviço manda outro executar algo de forma assíncrona.

**Forma:** a mensagem é um modelo pydantic imutável (`frozen=True`, `extra="forbid"`), com `version` e só identificadores, no `agenor-common`. Quem recebe recusa versão desconhecida e tem um tratador por tipo de mensagem.

**Referência:** `agenor_common/events.py` (`DispatchEvent`).

#### Observer

**Quando:** reagir a eventos que vêm de fora: Jobs do Kubernetes terminando (Launcher), mensagens chegando (Launcher).

**Forma:** um laço que recebe o evento externo (watch do Kubernetes, `receive` da fila) e o entrega a um tratador escolhido numa tabela `dict[TipoDoEvento, tratador]`. Dentro de um processo não há assinantes nem barramento de eventos: a ordem das ações fica explícita no serviço.

**Referência:** entra na fase 2 (A2.1 e A2.4).

#### Chain of Responsibility

**Quando:** etapas comuns a toda requisição.

**Forma:** middleware para o que vale para todas as rotas (log, métrica, rastreamento); dependência do FastAPI para o que vale para um grupo (autenticação por papel, sessão do banco). A rota só começa depois da cadeia.

**Referência:** `app/main.py` (middlewares), `app/auth.py` e `app/database.py` (dependências).

#### Factory de teste

**Quando:** montar dados para um teste.

**Forma:** funções `make_<entidade>(**overrides)` com valores padrão válidos, num `tests/factories.py` por repositório. O teste muda só o que importa para ele.

```python
def make_collection(**overrides: Any) -> Collection:
    fields = {"collection_type": CollectionType.GPS, "client_document": "12345678000190", ...}
    return Collection(**(fields | overrides))
```

**Referência:** `agenor-document-collector/tests/factories.py` (`make_collection`, `make_attempt`, `add_collection_with_attempt`).

## 3. SOLID

Regras obrigatórias. Cada uma diz o que fazer e como a revisão confere.

| Princípio | Regra | A revisão confere |
|---|---|---|
| **S** — Responsabilidade única | Cada módulo e cada função têm um motivo para mudar. Rota: HTTP. Serviço: regra. Repositório: consulta. Adaptador: a tecnologia externa | Rota com regra ou SQL; serviço com `HTTPException` ou SQL cru; função de serviço com mais de um caso de uso |
| **O** — Aberto/fechado | Variação nova entra por extensão: uma entrada nova num registro de [Strategy](#strategy), um adaptador novo, um worker novo. O que já funciona não é editado para acomodar um tipo novo | `if tipo == ...` ou `match` por tipo de coleta fora do registro |
| **L** — Substituição de Liskov | Toda implementação de um `Protocol` passa na mesma suíte de comportamento que as outras | Adaptador ou fake sem a suíte (como o `test_queue_behavior.py` da fila) |
| **I** — Segregação de interface | `Protocol` com só o que quem usa precisa. Dois usos diferentes, dois `Protocol`s | Método que uma implementação deixa vazio ou levanta `NotImplementedError` |
| **D** — Inversão de dependência | Serviço depende de `Protocol` e recebe a implementação por parâmetro ou `Depends`; a escolha concreta fica na borda (Factory Method, configuração). Sem contêiner de injeção | Serviço que importa um adaptador concreto (`OciQueue`, `Minio`); teste de serviço que precisa de rede |

**Com o SOLID, três regras de igual peso:**

- **KISS:** a forma mais simples do padrão que resolve o problema.
- **YAGNI:** só o que a arquitetura precisa agora (mesmo critério do modelo de dados).
- **DRY:** cada regra de negócio num lugar só (status, retentativa, catálogo de eventos). Código parecido vira abstração no terceiro uso, não no segundo.

## Adequação do código existente (29/10)

Feita antes da A1.6, para a #341 seguir já no padrão:

- **State:** `app/services/orchestration/states.py`, com a tabela de transições e o teste de cada uma; o `start` e o `finish` passam por `transition_attempt`. Os erros de domínio foram para `errors.py`.
- **Factory Method:** `create_queue` com `match` no enum.
- **Singleton:** a fila do DC (`app/clients/queue.py`) com `@cache` e `cache_clear` no fechamento.
- **Factory de teste:** `tests/factories.py` no DC, no lugar das três funções repetidas.
- **Nomes:** os testes e os scripts com nome em português passaram para o inglês (`export_openapi_v2.py`, `probe_agnaldo_token.py`, `export_contract.py`).
- **Docstring do padrão** nos adaptadores de fila, no `JwksKeyProvider`, no repositório e no serviço de tentativas.

**Herdado, que entra no padrão na atividade em que for tocado:** `app/main.py` (`loguru`, middleware do Ledger, `domains/billing`) na A1.14; os schemas do consumidor (a cadeia de `if collection_type == ...` em `unified.py` vira registro por enum), `app/dependencies.py`, os clientes do bucket (sem `Protocol`) e o repositório e o serviço de filiais na A1.16. As exceções ficam no `pyproject.toml`, cada uma com o motivo.
