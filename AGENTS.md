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
| `docs/arquitetura/` | este | ADRs e `infra.md` |
| `referencia/` | nenhum | Snapshots do scraper e do download service, só para consulta |

Os repositórios ainda não têm remoto. Depois terão dois: o GitHub da Solfy e o Bitbucket do cliente.

## Plano e decisões

- Plano (fonte de trabalho): `docs/PLANO_AGENOR_2_0.md`. Status das atividades, roadmap e pontos de atenção estão nele.
- Contexto e histórico das decisões: `docs/CONTEXTO_E_DECISOES.md`.
- Diagnóstico do sistema atual: `docs/RELATORIO_DIAGNOSTICO_AGENOR.md`.
- Documentos enviados pelo cliente: `docs/cliente/` (só referência de intenção; ver o contexto).
- As decisões técnicas viram ADRs em `docs/arquitetura/`. Consulte o ADR antes de mudar algo que ele cobre.

## Regras comuns

- **Local primeiro.** Tudo é desenvolvido e validado localmente, com fila e armazenamento locais. Os ambientes (dev, stg, prd) são a última etapa.
- **Só o schema `agenor_v2`.** O v2 divide o banco com o DC atual e o AGuiar, mas escreve só no `agenor_v2`. Nunca cria, altera ou grava tabelas do `public`, e a `alembic_version` do v2 fica dentro do `agenor_v2`. Os status novos (`CANCELLED`, `NO_SESSION`, `INFRA_FAILED`) existem só no v2.
- **Nenhuma credencial** no código, nos values do Helm ou nos commits. Tudo vem de Secret ou variável de ambiente. Não leia nem copie arquivos `.env`.
- **Commit no repositório do serviço alterado.** Uma mudança que atravessa repositórios vira um commit em cada um. Esta pasta só recebe commits de documentação.
- **`referencia/` é só leitura.** O código portado entra no `agenor-workers`, com testes.
- **Stack:** Python 3.12, `uv`, `pydantic-settings`, `ruff` e `pytest`. O DC herdou `black`, `isort` e `flake8` do DC atual (ver o `AGENTS.md` dele).

## Verificação

```bash
scripts/agent/verify.sh
```

Roda o `scripts/agent/verify.sh` de cada repositório (lint e testes) e resume o resultado de cada um. Sai com código diferente de 0 se algum falhar. O estado conhecido de cada repositório está no `AGENTS.md` dele.

Para conferir o harness do Claude Code (`.claude/`), numa sessão aberta com `claude` na raiz do `agenor-v2`:
- `/memory` lista este `AGENTS.md`; o de cada repositório carrega quando um arquivo dele é lido;
- `/agents` mostra o `revisor-isolamento-banco`;
- `/hooks` mostra o `PreToolUse` (`Bash`, bloqueio de comandos perigosos) e o `PostToolUse` (`Edit|MultiEdit|Write`, `ruff` nos `.py`).
