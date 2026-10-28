# Ambiente local

Ambiente da A0.5, onde tudo é desenvolvido e validado antes dos ambientes do cliente (plano, §4, "Ambiente local"). Nada daqui fala com a OCI nem com o banco compartilhado.

```bash
local/up.sh          # sobe tudo e roda o check.sh no fim (idempotente)
local/check.sh       # confere o ambiente
local/down.sh        # para os containers; dados e cluster continuam
local/down.sh --all  # apaga também os volumes e o cluster
```

Pré-requisitos: Docker (OrbStack), `kind` (`brew install kind`) e `kubectl` (vem com o OrbStack).

## O que sobe

| Peça | Onde | Observação |
|---|---|---|
| Postgres 13 | `127.0.0.1:5428`, banco `document_collector`, usuário `agenor` / `agenor-local` | Esquema criado pelas migrações do DC atual, no start dele |
| S3 local (SeaweedFS 4.45) | `http://127.0.0.1:8333` | Buckets `hiperautomacao-agenor-local` e `hiperautomacao-aguiar-local`; aceita qualquer chave de acesso |
| DC atual | `http://127.0.0.1:9092` (`/docs`, `/api/v1/health/`) | O commit de partida do DC (`fdd4c55`, staging `8d2212f`), sem alterações |
| Cluster kind | contexto `kind-agenor` | Para os Jobs do Launcher |

Senhas e chaves daqui são só do ambiente local, descartáveis.

- **DC atual separado do DC v2.** O `up.sh` extrai o commit `fdd4c55` do `agenor-document-collector` para `local/.generated/dc-atual` e constrói a imagem `agenor-local/dc-atual:8d2212f` a partir dele. O código do DC v2 muda; o DC atual não. Ele roda o entrypoint de produção, inclusive o `alembic upgrade head` no start: é o que a A1.15 usa para provar que ele sobe e reinicia com o schema `agenor_v2` presente.
- **Fila da OCI desligada.** O DC atual cria um cliente da OCI Queue no import e exige uma chave. O `up.sh` gera uma chave RSA descartável em `local/.generated/oci.env`, e o endpoint da fila aponta para `127.0.0.1:1`: nenhuma mensagem sai.
- **Pods alcançam os serviços pelo nome.** Os containers entram na rede Docker `kind`, então um pod do cluster chega em `http://dc-atual:9092` e `http://s3:8333`.
- **MinIO não é usado.** A MinIO deixou de publicar as imagens da edição comunitária (Docker Hub e Quay). O `docker-compose.yml` herdado do DC ainda a cita.

## Comandos úteis

```bash
docker compose -f local/compose.yaml logs -f dc-atual
docker compose -f local/compose.yaml restart dc-atual     # reinício do DC atual (A1.15)
psql postgresql://agenor:agenor-local@127.0.0.1:5428/document_collector
```

`kubectl` e `helm` sempre com `--context kind-agenor` (o hook do Claude Code bloqueia sem contexto local).

## O que vem depois

- **A1.4 e A1.12:** o DC v2 entra aqui, ao lado do DC atual e no mesmo banco: no compose para o dia a dia e no kind por manifestos simples (sem chart), com a migração como Job antes do deploy.
- **Imagens no kind:** o `kind load docker-image` falha com imagens multiplataforma no OrbStack. Para as imagens nossas, construir só para a arquitetura local ou usar `kind load image-archive`.
- **A1.17:** o adaptador local da fila.
- **Fase 2 (A2.8):** o Launcher no kind, por manifestos (Deployment, ServiceAccount e Role), e os Jobs dos workers.
