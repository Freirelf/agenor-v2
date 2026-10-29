# Agenor 2.0

Reconstrução da plataforma de coleta de documentos fiscais da AG Capital na Receita. Cada coleta roda num Kubernetes Job próprio, criado pelo Launcher, e o Document Collector é o único dono do status e da retentativa.

```
Agenor → Document Collector v2 → fila → Launcher → Job do worker (um por tentativa, um tipo por worker)
```

## Mapa

Esta pasta é uma pasta de trabalho. O Git dela versiona só a documentação; cada serviço é um repositório Git próprio (o `.gitignore` daqui ignora as pastas dos serviços). Cada repositório tem um `AGENTS.md` com os comandos e as armadilhas dele.

| Pasta | Git | O que é |
|---|---|---|
| `agenor-document-collector/` | próprio | DC v2, o orquestrador. Parte do DC atual exportado da staging (ver `ORIGEM.md`) |
| `agenor-launcher/` | próprio | Consome a fila e cria um Kubernetes Job por tentativa |
| `agenor-workers/` | próprio | `core/` (base comum) e `workers/` (um por tipo de coleta) |
| `agenor-common/` | próprio | Contratos (evento da fila, modelos da API) e interface de fila, instalado por tag Git |
| `docs/` | este | Plano, contexto e decisões, diagnóstico e documentos do cliente |
| `docs/arquitetura/` | este | Visão geral, ADRs, modelo de dados, padrões de código e `infra.md` |
| `referencia/` | nenhum | Snapshots do scraper e do download service, só para consulta |
| `local/` | este | Ambiente local (A0.5): Postgres, S3 local, DC atual e cluster kind. Ver `local/README.md` |
| `agenor-v2.code-workspace` | este | Workspace do VS Code com os cinco repositórios, cada um com a sua `.venv` |

Os cinco repositórios estão no GitHub (`origin`). O Bitbucket do cliente entra depois como segundo remoto.

## Plano e decisões

- Plano (fonte de trabalho): `docs/PLANO_AGENOR_2_0.md`. Status das atividades, roadmap e pontos de atenção estão nele.
- Contexto e histórico das decisões: `docs/CONTEXTO_E_DECISOES.md`.
- Diagnóstico do sistema atual: `docs/RELATORIO_DIAGNOSTICO_AGENOR.md`.
- Documentos enviados pelo cliente: `docs/cliente/` (só referência de intenção; ver o contexto).
- Arquitetura: `docs/arquitetura/visao-geral.md` (as peças, o caminho de uma coleta e qual documento manda em cada assunto).
- As decisões técnicas viram ADRs em `docs/arquitetura/`. Consulte o ADR antes de mudar algo que ele cobre.
- O modelo de dados do schema `agenor_coleta` está em `docs/arquitetura/modelo-de-dados.md`: cada tabela e coluna, com para que serve, quem escreve e quem lê. Toda tabela, coluna ou índice entra nele, com o ok do Lucas, antes do modelo e da migração (skill `nova-migracao-agenor-coleta`).
- **Ao concluir uma tarefa do Squads** (#337 em diante, ligadas às atividades na §6 do plano): atualize o status no topo do plano (o que foi concluído e a próxima tarefa) e o registro do dia no `docs/CONTEXTO_E_DECISOES.md`, terminando em **Próximo:**. Depois, mostre ao Lucas o que entraria em cada commit, por repositório, e só commite com a confirmação dele. O Squads é atualizado pelo Lucas.

## Como trabalhamos cada atividade

O padrão completo está em `docs/padroes-de-desenvolvimento.md` (pronto quando, Git, revisão, documentação) e o do código em `docs/arquitetura/padroes-de-codigo.md`. Os dois valem para todo o projeto.

O plano dá a direção; ele não é uma lista para executar ao pé da letra. Cada atividade (ou tarefa do Squads) é uma parte pequena, feita até o fim antes da próxima:

1. **Analisar** o que o plano e os ADRs pedem para ela.
2. **Verificar no código** o que existe de fato: o que reaproveitar, o que está quebrado, o que o plano não previu.
3. **Planejar a execução** e combinar com o Lucas antes de mudar a direção do plano ou de um ADR.
4. **Executar** no padrão de código: camadas (rota → serviço → repositório → modelo), tipado, testado, configuração validada e erros explícitos.
5. **Validar e testar** no ambiente local (`verify.sh` e, quando couber, `local/`).

Subagentes entram quando ajudam: uma revisão independente (por exemplo, o `revisor-isolamento-banco` antes de commitar migrações) ou uma busca ampla no código. Uma tarefa nova do Squads começa numa sessão nova, a partir do status no topo do plano e do **Próximo:** do contexto.

## Regras comuns

- **Local primeiro.** Tudo é desenvolvido e validado localmente, com fila e armazenamento locais. Os ambientes (dev, stg, prd) são a última etapa.
- **Só o schema `agenor_coleta`.** O v2 divide o banco com o DC atual e o AGuiar, mas escreve só no `agenor_coleta`. Nunca cria, altera ou grava tabelas do `public`, e a `alembic_version` do v2 fica dentro do `agenor_coleta`. Os status novos (`CANCELLED`, `NO_SESSION`, `INFRA_FAILED`, `TIMED_OUT`) existem só no v2.
- **Infra é do cliente.** Não altere `bitbucket-pipelines.yml`, `sonar-project.properties`, `helm/`, `kubernetes/` nem values. Um problema nesses arquivos vira alerta ao cliente (§3.10 do plano), não correção. **Não escrevemos chart nem values:** o DC v2 e o Launcher sobem no kind com manifestos simples em `local/`, que é nosso e só local, e para o cliente vai o `infra.md`.
- **Nenhuma credencial** no código, nos values do Helm ou nos commits. Tudo vem de Secret ou variável de ambiente. Não leia nem copie arquivos `.env`.
- **Commit no repositório do serviço alterado.** Uma mudança que atravessa repositórios vira um commit em cada um. Esta pasta só recebe commits de documentação e do que atravessa os repositórios (`scripts/agent/`, `local/`).
- **`referencia/` é só leitura.** O código portado entra no `agenor-workers`, com testes.
- **Stack:** Python 3.12, `uv`, `pydantic-settings`, `ruff`, `mypy` e `pytest`, com as mesmas regras nos quatro repositórios de código (`docs/arquitetura/padroes-de-codigo.md`).

## Verificação

```bash
scripts/agent/verify.sh
```

Roda o `scripts/agent/verify.sh` de cada repositório (lint e testes) e resume o resultado de cada um. Sai com código diferente de 0 se algum falhar. O estado conhecido de cada repositório está no `AGENTS.md` dele.

Para conferir o harness do Claude Code (`.claude/`), numa sessão aberta com `claude` na raiz do `agenor-v2`:
- `/memory` lista este `AGENTS.md`; o de cada repositório carrega quando um arquivo dele é lido;
- `/agents` mostra o `revisor-isolamento-banco`;
- `/hooks` mostra o `PreToolUse` (`Bash`, bloqueio de comandos perigosos) e o `PostToolUse` (`Edit|MultiEdit|Write`, `ruff` nos `.py`).
