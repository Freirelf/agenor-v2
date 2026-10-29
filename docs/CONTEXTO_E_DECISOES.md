# Agenor: contexto e decisões da fase de análise

Documento de passagem para as próximas sessões. Resume o que foi feito e decidido até 26/10/2026.

## O que foi feito

- **Análise diagnóstica, somente leitura,** de quatro repositórios do cliente:
  - `agenor-front`
  - `agenor-scraper-service`
  - `document-collector-service`
  - `agenor_download_service`
- Nada foi instalado, executado ou alterado nos repositórios.
- **Relatório técnico completo:** [RELATORIO_DIAGNOSTICO_AGENOR.md](RELATORIO_DIAGNOSTICO_AGENOR.md), versão 2, de 07/10.
  - É a referência técnica principal: produto, fluxos, arquitetura, banco, integrações, infra, débitos e riscos.
  - As versões e branches citados nele são de 07/10. Os mais recentes estão na tabela abaixo.
- **Relatório para o cliente:** documento "Agenor — Relatório de Análise Técnica" (claude.ai, privado).
  - É uma versão resumida e menos técnica.
  - Não assume que o sistema está funcional e não propõe arquitetura.

## Decisões tomadas

1. **Reformulação, não reescrita do zero.** O código existente serve de base.
2. **A reconstrução segue os padrões do produto Agnes Collector**, inclusive a integração com o **Agnaldo via API**, como o document-collector já faz.
   - O código do Agnaldo não precisa ser analisado.
3. **Infraestrutura:** é responsabilidade do cliente; o desenvolvimento é responsabilidade nossa.
   - As configurações de infra deles (pipelines, `kubernetes/`, `helm/`, `values`) vão junto para o repositório novo, para dar visibilidade.
   - As falhas encontradas nessa parte devem ser **alertadas** ao cliente, não corrigidas por nós.
4. **Estratégia de repositório:**
   - Repositório novo `agenor-v2`, em `/Users/lucasfreire/www/work/ag-capital/agenor-v2`.
   - O código entra por exportação, **sem histórico e sem vínculo** com os repositórios do cliente.
   - A origem de cada projeto é registrada em um `ORIGEM.md`.
5. **Ordem de trabalho:**
   - **Fase atual (alinhamento e planejamento):** usar os clones em `ag-capital/agenor/` como referência, atualizados com `git fetch`.
   - **Início do desenvolvimento:** exportar a versão mais recente para o `agenor-v2` (hoje a pasta está vazia e sem git).
   - **Mudanças do cliente depois da exportação:** aplicar com `git diff <commit-registrado> origin/<branch> | git -C agenor-v2 apply --directory=<pasta>`.

## Branches de partida (pendente de confirmação do cliente)

Mensagem enviada ao cliente pelo WhatsApp em 26/10, perguntando de qual branch partir. Até a resposta, a referência é:

| Projeto | Branch | Commit | Data |
|---|---|---|---|
| agenor-scraper-service | `staging` | `366304a` | 21/10/2026 |
| document-collector-service | `staging` | `8d2212f` | 22/10/2026 |
| agenor-front | `staging` | `26fb1d7` | 14/10/2026 |
| agenor_download_service | `feat/service-zip` | `94c5f37` | 19/08/2026 |

**Fora dessa base, para avaliar:**

- **`dev` do scraper:** foi realinhado e voltou a ser usado, com commit em 26/10. Tem 8 commits que não estão em `staging`:
  - remoção do coletor DCTFWeb legado e de código morto;
  - unificação de conectores;
  - pipeline novo;
  - ajuste de Redis.
- **Branches em andamento, ainda não mergeados:**
  - front: `chore/node-22-23-4` (atualização de segurança do Node);
  - document-collector: `refactor/Uow` (refatoração UnitOfWork).

## Mudanças do cliente desde a análise (07/10 → 26/10)

- **Scraper:** coleta de GPS por CEI, DARF via portal de serviços, opção de trazer só a planilha, ajuste de CNPJ na planilha DCTFWeb.
- **Document-collector:** tipo de coleta GPS por CEI, flag para trazer só o Excel, extração do PER/DCOMP Consultor, endpoints de consulta e update, 3 réplicas em produção.
- **Front:** correção do e-mail de suporte.

## Alinhamento com o cliente (26/10): arquitetura-alvo

Fluxo apresentado: **Collector (front) → Document Collector → fila → Launcher → workers por tipo**.

- **Document Collector:** orquestrador das coletas (recebe a solicitação e manda executar).
- **Fila:** continua entre o Document Collector e o Launcher.
- **Launcher (novo, sem repositório hoje):** consome a fila e sobe um pod para o tipo de coleta; o pod é derrubado ao fim do serviço (modelo inspirado em AWS Lambda). Substitui o consumo direto da fila pelo scraper.
- **Workers, um por tipo:** eSocial Collector, DCTFWeb, Fontes Pagadoras, PER/DCOMP, DARF, GPS. Cada um faz três coisas: ler a entrada vinda do Launcher, coletar e guardar.
- **eSocial é novo:** não existe coletor de eSocial no scraper atual (o termo só aparece em parsers do DCTFWeb).
- **Fonte de verdade é este alinhamento verbal.** Os documentos que o cliente enviou depois (`docs/cliente/`: um PDF de arquitetura e um DOCX com três histórias do pod) foram gerados por IA e servem só como referência de intenção. Têm contradições internas (ex.: o PDF diz que o Launcher envia a mensagem ao pod; a história diz que o pod consome a fila) e deixam em aberto todo o desenho técnico.

### Decisões (26/10)

1. **A parte técnica é nossa.** Desenho, contratos, tecnologia e estratégias (retentativa, idempotência, status, nomenclatura) são definidos por nós. Não viram perguntas ao cliente.
2. **O Launcher é nosso:** vamos desenvolver. O que precisar de infra (OCI, cluster, permissões, filas, buckets, segredos) é pedido ao cliente.
3. **Reformulação inclui o modelo de dados.** Mudar onde ficam os dados extraídos é escolha nossa; o impacto é esperado e deve ser planejado, não evitado.

### Insumos levantados para o desenho

- **Consumidores das extrações:** os endpoints `consult_*` do DC (`app/routers/router_extract.py`) **não são chamados pelo front nem pelo scraper**. O único uso interno é o `query_consult` (SQL livre) chamado pelo scraper no PER/DCOMP. Quem consome as extrações hoje é desconhecido; isso é fato a apurar (cluster/logs/cliente), não decisão.
- **Já existe no scraper e serve ao worker:** chaves determinísticas no bucket, deduplicação com Redis (`app/utils/deduplication/`), status FINISHED_EMPTY e PARTIALLY_FINISHED.

## Próximo passo

O plano está em [PLANO_AGENOR_2_0.md](PLANO_AGENOR_2_0.md). Primeira versão completa em 26/10:
- etapas 1 a 4 (visão, papéis, planejamento técnico, roadmap) validadas;
- etapa 6 (atividades) escrita;
- padrões do Agnes Collector (`agnes-collector`, branch `feature/oci-queue`) incorporados na §3.12.

- etapa 5 publicada (privada até compartilhar):
  - documento base: https://claude.ai/artifact/5i1RR8SQi4BdQ1abBdKavK
  - slides: https://claude.ai/artifact/619LxnSFfushYgKdLhiqJZ
- guia de conceitos de infra (Launcher, pod, Job, fila, Helm etc.) com índice de termos: https://claude.ai/artifact/KSDMiZdFLpNii6PBz1Yxxz

**Próximo:** refinamento de tudo (prazos inclusive). O desenvolvimento só começa depois disso. Mudanças no plano entram primeiro no `PLANO_AGENOR_2_0.md` e depois são levadas ao documento e aos slides.

### Refinamento, rodada 1 (26/10)

**Etapas 1 a 4 revisadas.** Decisões:
- **Duas releases no mesmo banco.** O DC v2 sobe em release própria, ao lado do DC atual, que fica intacto para o AGuiar e o scraper.
  - A virada é apontar os consumidores para o v2.
  - Não há chave de ambiente.
- **O v2 fica isolado das tabelas do DC atual,** com tabela de tentativas própria e `alembic_version_v2`. A forma exata vai para ADR.
- **Novo status de tentativa:** `CANCELLED`.
- **Pontos de atenção consolidados na §3.13** do plano.
- **Nível de detalhe:** o plano fica no nível de decisão (escopo, ordem, prazo, infra, risco), e o detalhe técnico vai para os ADRs da A0.6.
- **Local primeiro:** tudo é validado e testado no ambiente local (M1 a M3). DEV, STG e PRD ficam como a última etapa (fase 6, M4 a M6).
  - Agora o único pedido ao cliente é a branch de partida.
  - O esquema do banco vem das migrações, e os usuários de serviço do Agnaldo já existem.
  - Fila e armazenamento são locais: a fila tem uma interface com um adaptador local e outro da OCI.
  - Os acessos de teste aos portais e a infra dos ambientes são alinhados no decorrer do desenvolvimento.
- **Documento para o cliente:** `ag-capital/agenor/entregaveis/Agenor_2_0_Plano_de_reformulacao.pdf`, em 2 páginas, com a pergunta sobre o AGuiar e o banco compartilhado.

**Ainda não foi feito:**
- revisão item a item das atividades e da §3.10;
- prazos;
- atualização do documento base e dos slides.

Até 27/10, só a sessão de refinamento editava o `PLANO_AGENOR_2_0.md`. Desde então, o plano é versionado em `agenor-v2/docs/` e editado no ambiente do v2.

### Refinamento, 27/10

- **Produto novo:** o 2.0 é a reconstrução do Agenor, em repositório e schema próprios (`agenor_v2`, no mesmo banco).
  - Reaproveita processos do sistema atual, não a estrutura.
  - O destino do sistema atual, inclusive para o AGuiar, é decisão do cliente e não vira pergunta.
- **Extração:** os workers rodam os parsers atuais e guardam o resultado em JSON no bucket.
  - Tabelas de extração, API de consulta e cópia do histórico ficam para depois (fase 5 fora desta versão).
  - Antes da virada, identificar quem chama `/extracoes` e `consult_*` (§3.13, item 19).

### Refinamento, rodada 2 (27/10): alicerce pronto para começar

- **Atividades das fases 0 a 2 revisadas item a item** (§6 do plano). Entraram:
  - a API do consumidor (A1.16);
  - a interface de fila (A1.17);
  - a limpeza do DC v2, inclusive do orquestrador e dos sweepers antigos (A1.13);
  - os acessos de teste (A0.8).
- **Branch de partida:** não esperamos o cliente. Partimos da branch mais atual de cada projeto, registrada no `ORIGEM.md`.
- **Prazos:** Lucas, 8 h por dia, desenvolvendo com o Claude Code. Cerca de 98 h no total.
  - M0 em 29/10;
  - M1 em 13/11, ou 18/11 com folga.
- **Acompanhamento:** projeto "AG Capital - Agenor" no Squads (squads.solfy.tech), tarefas #337 a #346, visíveis ao cliente.
  - Ligação entre as tarefas e as atividades: §6 do plano.
- **PDF para o cliente** (`ag-capital/agenor/entregaveis/`):
  - etapa 3 = "Validação e testes", tudo local;
  - os ambientes só são citados como o final;
  - nenhum pedido ao cliente para começar.
- **Documento base e slides antigos:** desatualizados. A recomendação é aposentá-los, porque o PDF os substitui (decisão pendente).

### Desenvolvimento, 27/10

- **#337 concluída** (A0.1 a A0.3): `agenor-v2` com quatro repositórios separados (DC v2, Launcher, workers e `agenor-common`), um repositório de docs e a `referencia/` fora do Git.
- **Harness:** `AGENTS.md` como fonte única de contexto (lido nativamente pelo Claude Code; sem `CLAUDE.md`), `verify.sh` por repositório, hooks e o subagente revisor do isolamento do banco. Skills só depois da primeira migração (#340) e do piloto.
- **Documentos de trabalho** versionados em `agenor-v2/docs/`.
- **DC herdado:** testes corrigidos na A0.4 (condição do M0); `ruff` adotado no fim da A1.13.

**Próximo:** #338 (A0.6): a §3 do plano convertida em ADRs e o `infra.md`.

### Desenvolvimento, 27/10: #338 (A0.6)

- **Nove ADRs em `docs/arquitetura/`,** a partir da §3 do plano, no formato do Agnes Collector:
  - 001 isolamento no schema `agenor_v2`;
  - 002 tentativa e status;
  - 003 contratos;
  - 004 despachante e retentativa;
  - 005 Launcher com Kubernetes Jobs;
  - 006 autenticação por usuários de serviço do Agnaldo;
  - 007 workers por tipo com base comum;
  - 008 observabilidade;
  - 009 virada única pelos consumidores.
- **`infra.md`:** só o que o código precisa do ambiente (banco, fila, bucket, cluster e RBAC, autenticação, imagens, rede, recursos, observabilidade), com a coluna local e a dos ambientes. Cada item diz se já está definido, se sai de uma atividade (com o código dela) ou se depende do cliente.
- **Plano:** as §3.1 a §3.9 viraram resumos com links para os ADRs. As §3.0 e §3.10 a §3.13 continuam no plano. Uma mudança de decisão técnica entra primeiro no ADR.
- **Detalhes fixados na conversão:**
  - `STARTING` = o Launcher criou o Job. A publicação na fila fica em `dispatched_at`, não no status.
  - O limite de concorrência é só do DC: saiu do catálogo do Launcher.
  - Abandono e aviso do Launcher sobre o mesmo Job: o primeiro encerra a tentativa, e o segundo é ignorado.
- **Ficam em aberto nos ADRs:** a regra exata do cálculo de status (A1.7) e a forma de validar o token do Agnaldo (A1.2). Os nomes de variáveis "a definir" no `infra.md` são fixados nas atividades indicadas.

**Próximo:** #339 (A0.4 e A0.5): CI de qualidade nos quatro repositórios, com os testes herdados do DC passando, e o ambiente local.

### Desenvolvimento, 27/10: #339 (A0.4 e A0.5), M0 atingido

- **Testes herdados do DC (A0.4):** de 560 passando, 54 falhas e 109 erros para 715 passando e 2 pulados (`skip` herdados).
  - O `tests/conftest.py` define as variáveis exigidas pelo `Settings`, sobrepondo o shell e o `.env`, com o Postgres na porta 1, e troca o cliente da OCI Queue por um mock. Um teste de rota abria conexão com o banco; agora substitui o `get_db`.
  - Testes desatualizados foram alinhados ao código da staging, que é a referência. Foram removidos os testes de código que não existe mais (`DataBaseService`, o schema antigo do `consult_perdcomp`, que sai na A1.13) e o do `get_collection_service`, que é código morto e quebrado.
  - O código da staging tem o status `FILE_NOT_FOUND`, que o plano não listava; entrou no ADR-002.
- **CI fica fora por enquanto (decisão do Lucas, 27/10).** Pipelines, Sonar e Helm são infra do cliente: se alterarmos, a responsabilidade passa a ser nossa. Um CI no Bitbucket e um no GitHub chegaram a ser escritos e foram desfeitos antes do commit. Problemas nesses arquivos viram alerta ao cliente, não correção. O `verify.sh` de cada repositório continua sendo a verificação, rodada localmente.
  - **Alerta novo:** o `bitbucket-pipelines.yml` herdado no repositório do DC v2 faz build e deploy da release `document-collector-service` nos namespaces do DC atual, e usa a chave do Sonar do DC atual. Se o v2 entrar no Bitbucket do cliente com esse arquivo, um push em `dev` ou `staging` sobrescreve o DC atual. Entrou nos alertas da §3.10.
  - Ficaram o `pytest-cov` nos três esqueletos e o `verify.sh` mostrando o log inteiro do passo que falhar quando `CI` está definido.
- **Commits:** passam a ser mostrados ao Lucas e só entram com a confirmação dele (regra no `AGENTS.md`).
- **Ambiente local (A0.5), em `local/` na raiz:** o `up.sh` sobe e confere o ambiente, e o `check.sh` confere. Peças:
  - Postgres 13 na porta 5428;
  - S3 local com SeaweedFS (a MinIO deixou de publicar imagens da edição comunitária);
  - DC atual construído do commit de partida (`fdd4c55`), sem alterações e separado do código do v2, com a fila da OCI apontada para um endpoint inalcançável;
  - cluster kind (`kind-agenor`), com os pods alcançando o DC e o S3 pelo nome.
  - O DC atual sobe, reinicia e roda o `alembic upgrade head` no start. É a base da A1.15.
- **M0 atingido:** os testes atuais passam, e o ambiente local sobe o DC atual sobre o banco local. O CI de qualidade, que a A0.4 previa, fica para quando for combinado com o cliente.

**Próximo:** #340 (DC 2.0, base): contrato em OpenAPI e esquema do evento (A1.1), validação do token do Agnaldo (A1.2), migrações no `agenor_v2` (A1.3), chart do DC v2 (A1.4), limpeza do DC v2 (A1.13) e interface de fila (A1.17).

### Refinamento, 28/10: sem chart nem values

- **O kind continua.** É só local, como o Postgres e o S3 do `local/`, e o Launcher precisa de um cluster para criar Jobs. Não é infra do cliente.
- **Não escrevemos chart nem values,** nem como sugestão: são o artefato de deploy, e entregá-los traria a responsabilidade do deploy para nós.
  - O DC v2 e o Launcher sobem no kind com manifestos simples em `local/`.
  - A migração roda como um Job local antes do DC v2.
  - Para o cliente vai o `infra.md`; chart, values, pipeline e deploy (A6.2) são dele.
- **Ajustes:**
  - A1.4: imagem do DC v2 com comando de migração separado, mais os manifestos locais.
  - A2.8: manifestos locais do Launcher.
  - Pedidos 5 e 10: incluem chart e values, e a migração como etapa separada.
  - ADR-001 e `infra.md`: a migração como etapa separada antes do deploy; o hook do Helm passa a ser só um exemplo, e a escolha é do cliente.

**Próximo:** #340 (DC 2.0, base): contrato em OpenAPI e esquema do evento (A1.1), validação do token do Agnaldo (A1.2), migrações no `agenor_v2` (A1.3), imagem com migração separada e manifestos locais (A1.4), limpeza do DC v2 (A1.13) e interface de fila (A1.17).

### Desenvolvimento, 28/10: #340 (A1.1 a A1.4, A1.13, A1.17), DC 2.0 base

Implementada e testada localmente; os commits esperam a revisão do Lucas, que pediu para ver as alterações antes (nada foi commitado).

- **Sequência confirmada com o Lucas:** limpar o DC v2 de tudo o que usa o `public` já na A1.13, como o plano dizia. A API do consumidor volta na A1.16 sobre o `agenor_v2`. No intervalo, o DC v2 não tem essas rotas, sem custo: nada do v2 vai para ambiente antes da fase 6.
- **A1.1, contrato:**
  - API do worker e do Launcher sob `/api/v2`, com modelos no `agenor_common.api` e OpenAPI gerado em `contrato/openapi-v2.json` do DC (há teste de igualdade). As rotas respondem 501 até a A1.5, A1.6 e A1.10.
  - Do consumidor, um retrato da API atual: as 7 chamadas que o front faz. As rotas legadas por tipo, a `coleta-completa` e a `reprocessar` ficam fora até aparecer consumidor delas (conferir nos logs do Agnaldo/APISIX antes da virada).
  - O `DispatchEvent` passou a ter tipo e identificadores tipados (enum e UUID), com o esquema publicado em `contrato/` do `agenor-common`.
- **A1.2, token:** a sondagem (`scripts/sondar_token_agnaldo.py`) mostrou que:
  - o `/auth/token` espera formulário;
  - o token é JWT RS256 do realm `agnes` do SSO, sem papel do serviço;
  - o JWKS é público.

  Decisão, registrada no ADR-006: validação local pelo JWKS e autorização por lista de usuários de serviço (`AUTH_WORKER_USERS`, `AUTH_LAUNCHER_USERS`). Validado com o token real do `solfy_coleta`, também no DC v2 rodando no compose.
- **A1.13, limpeza:**
  - saíram as rotas, os serviços, os modelos e as migrações do `public`, o AGuiar, o orquestrador, os endpoints de teste e de debug, o CORS aberto, o log da URL do banco com senha e as dependências sem uso;
  - ficaram os schemas de pedido e de resposta, o banco do company-service, o storage e a observabilidade;
  - os testes foram de 715 para 387 com a limpeza, porque os que saíram testavam código removido. Com os testes novos da #340, são 424, e 3 pulados.
  - **O plano previa** um consumo da fila antiga e sweepers dentro do DC: não existiam. O orquestrador rodava como CronJob do chart, que é do cliente e virou alerta.
  - **Achado:** o `greenlet` só vinha de carona pelo `locust`. O DC passou a declarar `sqlalchemy[asyncio]`.
- **A1.17, fila:**
  - interface assíncrona com três adaptadores: em memória, local e OCI. O local é uma tabela `fila_local.message` no Postgres do ambiente local, que atravessa processos e reproduz a OCI (visibilidade, recibo por entrega, reentrega e DLQ). O da OCI lê o `config` do SDK em arquivo;
  - o DC recusa a fila local fora do ambiente local;
  - os mesmos testes rodam na fila em memória e na local.
- **A1.3, migrações:**
  - tabelas `collection`, `attempt`, `item` e `event` no `agenor_v2`, com status em texto e `CHECK`, uma tentativa ativa por coleta (índice único parcial) e índices do despachante;
  - o `env.py` cria o schema só se faltar, segura uma trava com prazo e só enxerga o `agenor_v2`. Comando: `python -m app.migrate`;
  - testes em bancos descartáveis do Postgres local;
  - no banco local do DC atual, o `public` ficou idêntico antes e depois, e o DC atual reiniciou com health 200;
  - o `revisor-isolamento-banco` confirmou o isolamento. Os achados dele (permissão de `CREATE SCHEMA`, trava sem prazo, DSN de teste não local) foram corrigidos, e os do entrypoint e do Dockerfile, resolvidos na A1.4.
- **A1.4, imagem:**
  - `Dockerfile` sem root e com `uv` fixado; o `entrypoint.sh` só sobe a API, e a migração é `python -m app.migrate`;
  - no `local/`, o DC v2 roda no compose (`127.0.0.1:9094`) depois do `dc-v2-migrate`, e no kind pelo `local/dc-v2-kind.sh` (Job de migração, depois o Deployment);
  - o `check.sh` confere os dois DCs.
- **Skill nova:** `.claude/skills/nova-migracao-agenor-coleta/`.
- **Alertas novos ao cliente (§3.10):** o pipeline herdado faz `docker build .` sem o contexto do `agenor-common`, e o CronJob do chart chama um módulo que não existe no v2.

- **Ajuste na A1.3 (pedido do Lucas): revisão pelo autogenerate.**
  - O modelo passou a declarar os CHECKs de status como constraints nomeadas da tabela, e a `0001` foi regenerada pelo autogenerate, com edição só no docstring.
  - A comparação do DDL mostrou que a versão escrita à mão gerava nomes duplicados (`ck_collection_ck_collection_status`). A gerada sai com os nomes do modelo.
  - Dois testes novos conferem o que o autogenerate não compara: os nomes das constraints no banco e os valores de cada CHECK, que precisam bater com os enums do modelo.
  - O `revisor-isolamento-banco` confirmou o isolamento da revisão regenerada.
  - O nome e o identificador da revisão também passaram a ser do Alembic: o `file_template` do `alembic.ini` põe a data na frente (`20261028_9fd63faacdde_agenor_v2_inicial.py`), sem `rev_id` fixo nem arquivo renomeado.
  - A skill e os documentos agora dizem que o padrão é gerar e revisar.

- **Commits (confirmados pelo Lucas):** `agenor-common` 5ccc8fd, `agenor-document-collector` 1e6844b e raiz ba9c587.
- **`ruff` no DC v2, num commit só de formatação:**
  - substitui o `black`, o `isort` e o `flake8`, com `line-length = 120` e as regras padrão;
  - além da formatação, entraram as correções automáticas (tipos no estilo novo, imports ordenados e sem uso) e algumas correções manuais equivalentes (`raise e` → `raise`, `if`s aninhados juntados, import duplicado e variáveis sem uso);
  - o que mudaria comportamento ficou em `per-file-ignores`, com o motivo: `except` genérico em código herdado, `ValueError` em validador do Pydantic e o `Config` de classe dos schemas antigos;
  - o `verify.sh` do DC passou a rodar `ruff check` e `ruff format --check`, e o hook de formatação do Claude Code passa a valer no DC;
  - o `alembic.ini` passou a rodar o `ruff` em toda revisão gerada (`post_write_hooks`), para ela sair no formato do repositório sem edição;
  - desde então, mudanças da origem se portam à mão.

**Próximo:** a #341 (A1.5 a A1.11: DC 2.0, orquestração), a partir dos endpoints de entrada, início, sinal de vida e fim da tentativa (A1.5).

### Desenvolvimento, 29/10: modelagem de dados do `agenor_v2` (A1.3b)

A #341 (orquestração) começou pelo levantamento no código e parou ali, por decisão do Lucas: antes de escrever os endpoints sobre as tabelas, o modelo delas precisa ser pensado.

- **Por que entrou:** a A1.3 foi da lista de tabelas do ADR-002 direto para a migração, sem uma etapa de modelagem. Só o lado do worker e do despachante foi pensado, e o modelo trouxe colunas que repetem outras (`collection.technical_failures` e `business_retries` contam o que já está nas tentativas; `request_payload` repete as colunas de entrada), colunas de partes que ainda não foram detalhadas (ZIP, listagem do consumidor) e dados de diagnóstico misturados com estado.
- **Numeração:** A1.3b, logo depois da A1.3, porque refaz o resultado dela sem renumerar as atividades seguintes; a A1.3 continua ✅ com o seu histórico. A A1.5, A1.6, A1.8, A1.11 e A1.16 passaram a depender da A1.3b.
- **Critério (decisão do Lucas):** o modelo puxa só o que a nova arquitetura precisa agora: a API do worker e do Launcher, o despachante, a retentativa, o abandono e a regra de status (ADR-002 a ADR-004). O contrato que o front usa hoje (`contrato/consumidor-dc-atual.openapi.json`) é referência, não requisito: um campo dele só vira coluna se um fluxo atual precisar. O fluxo completo do consumidor ainda não é conhecido, então o modelo é declaradamente inicial e muda por migração quando cada parte for detalhada.
- **Entregável:** `docs/arquitetura/modelo-de-dados.md`, e não um ADR: é um catálogo vivo (cada coluna com para que serve, quem escreve e quem lê), que muda a cada migração; as decisões que saírem dele entram nos ADRs que elas afetam (ADR-002, ADR-004 e ADR-007).
- **Confirmado no código do DC atual:** a `ic_service_execution` é a auditoria das chamadas HTTP do coletor DARF ao Integra Contador (`POST /coleta-documentos/{id}/ic-executions`), não uma execução de coleta.
- **Brecha no harness:** nada exigia modelagem antes de uma migração. A proposta é que toda tabela ou coluna do `agenor_v2` entre primeiro no `modelo-de-dados.md`, e que o `revisor-isolamento-banco` confira se o modelo e o documento batem.

- **Aprovado pelo Lucas (29/10)**, com as 7 decisões do documento:
  1. `collection.technical_failures` e `business_retries` saem: a retentativa conta as tentativas da coleta quando uma termina, com a linha da coleta travada (ADR-004).
  2. `request_payload` sai: repetia as colunas de entrada.
  3. Um tipo só: `attempt.attempt_type` e `collection.zip_file_key` saem. O ZIP continua worker; como ele se liga à coleta no banco se decide na fase 4 (ADR-007).
  4. `job_created_at`, `job_name`, `pod_name`, `worker_version`, `started_at` e `finished_at` saem da tentativa e vão para os eventos `attempt.job_created`, `attempt.started` e `attempt.finished`. A API não muda (ADR-002).
  5. `item.report_type` em texto, sem catálogo: quem conhece os documentos de cada tipo é o worker.
  6. Nenhum campo do contrato do front vira coluna agora: cada um está marcado como derivado ou fora agora.
  7. `updated_at` sai da coleta e da tentativa (o item mantém o dele, porque não há evento por item), e os índices sem leitor saem.
- **Migração:** a `0001` foi regerada pelo autogenerate (`20261029_a057fe7dbe85_agenor_coleta_inicial.py`), com edição só no docstring, e substitui a `9fd63faacdde` da A1.3, que só tinha sido aplicada no banco local. No `local/`, o schema `agenor_v2` foi apagado e recriado pela migração nova. O `public` ficou idêntico antes e depois (colunas, constraints e versão do Alembic), o DC atual reiniciou com health 200 e o `check.sh` passou.
- **Testes:** 424 passam e 3 são pulados no DC. Só o `test_models_agenor_v2.py` mudou: tirou o `attempt_type` e o `technical_failures`.
- **Harness:** o `AGENTS.md` do DC e a skill `nova-migracao-agenor-coleta` (passo 0) exigem que toda tabela, coluna ou índice entre primeiro no `modelo-de-dados.md`, com o ok do Lucas. O `revisor-isolamento-banco` ganhou a regra 6: o modelo e o documento batem.
- **`revisor-isolamento-banco`:** ISOLADO, já com a regra 6. Os dois achados da regra 6 eram do documento, que não registrava os padrões das colunas nem o tamanho (32) dos campos de status; foram corrigidos. Observação dele, anotada no documento para a A1.6: o `onupdate` do `item.updated_at` não vale num `INSERT … ON CONFLICT DO UPDATE`, então o upsert grava `updated_at = now()` explicitamente.
- **Banco local com a revisão antiga:** um `agenor_v2` que tenha a `9fd63faacdde` não migra mais ("Can't locate revision"). O remédio é `DROP SCHEMA agenor_v2 CASCADE` no Postgres do `local/`, só do v2, e `python -m app.migrate`. O DC v2 no kind usa o mesmo Postgres do compose, já recriado.
- **Schema renomeado para `agenor_coleta` (decisão do Lucas, 29/10).** Antes do commit da A1.3b, o Lucas questionou o nome `agenor_v2`: o schema não é temporário e, depois da virada, um "v2" no nome perderia o sentido. Ficou `agenor_coleta`, que diz que o schema é da coleta do Agenor feita por nós. A pasta de trabalho continua `agenor-v2`, e o "v2" do `/api/v2` (versão da API) e o nome "DC v2" também ficam.
  - Era o momento mais barato: a migração só tinha sido aplicada no banco local. Não sabemos se o banco de produção tem um schema com esse nome; o Lucas acredita que não, e a conferência vai junto com o pedido 11 ao cliente.
  - Mudaram o `SCHEMA` do modelo (o `env.py` e os testes o usam), os nomes dos arquivos (`app/models/agenor_coleta.py`, `tests/test_*_agenor_coleta.py`, o ADR-001 e a skill `nova-migracao-agenor-coleta`) e as menções nos documentos, no `local/`, no harness e num docstring do `agenor-common`. As entradas anteriores deste contexto continuam com `agenor_v2`, porque registram o que aconteceu.
  - A `0001` foi regerada outra vez: `20261029_a057fe7dbe85_agenor_coleta_inicial.py`. No `local/`, o `agenor_v2` foi apagado e o `agenor_coleta` criado pela migração. O `public` ficou idêntico, o DC atual reiniciou com health 200, o DC v2 foi reconstruído no compose e o `check.sh` e o `verify.sh` passaram.

**Próximo:** a #341 (A1.5 a A1.11: DC 2.0, orquestração), a partir dos endpoints de entrada, início, sinal de vida e fim da tentativa (A1.5), sobre o modelo da A1.3b.

### Desenvolvimento, 29/10: #341 (A1.5 a A1.11), DC 2.0 orquestração

- **Plano de execução (aprovado pelo Lucas em 29/10).** Ordem: fundação, A1.11, A1.5, A1.6, A1.7, A1.9, A1.8, A1.10. O despachante vem depois da retentativa porque a varredura dele também roda o abandono. Nenhuma mudança de tabela prevista. Decisões, todas com a recomendação aceita:
  1. **Status da coleta (A1.7):** `PENDING` até o Job ser criado; `PROCESSING` com o Job criado, o worker rodando ou uma retentativa técnica ou de negócio (`FAILED` recuperável) esperando; `WAITING_SESSION` com retentativa esperando por `NO_SESSION`. No fim, pelos itens: todos com arquivo → `FINISHED`; sem arquivo ou todos `FILE_NOT_FOUND` → `FINISHED_EMPTY`; concluídos e `FAILED` misturados → `PARTIALLY_FINISHED`; todos `FAILED` → `FAILED`. Retentativas esgotadas ou falha não recuperável: `FAILED`, ou `PARTIALLY_FINISHED` se algum item já tiver arquivo, com o motivo no `status_text`. O status `FILE_NOT_FOUND` da coleta não é produzido (a regra do DC atual também nunca o produzia). Vai para o ADR-002.
  2. **Limite da retentativa de negócio:** 10 por padrão (cerca de 8 h de espera), configurável por tipo. O ADR-004 dizia "até o limite do tipo", sem número.
  3. **Varredura dentro do processo da API**, a cada 1 min, com `pg_try_advisory_xact_lock`: só uma réplica varre por vez, sem Deployment novo para o cliente.
  4. **Vigente e cancelada:** vigente é a tentativa não encerrada. O `active` do `input` e do `heartbeat` também exige a coleta não cancelada. Numa coleta cancelada, `items` e `finish` continuam aceitos (o worker precisa encerrar com `CANCELLED`). `CANCELLED` do worker sem cancelamento pedido recebe 409, para não gerar tentativas novas sem fim.
  5. **Criação da coleta:** `create_collection()` só de domínio nesta tarefa (coleta, tentativa 1, eventos e despacho); a rota é da A1.16.
  6. **Achado: `force`.** No DC atual era "criar a coleta mesmo com outra em andamento", não "coletar de novo os itens concluídos", como dizem o contrato e o modelo. A coluna fica; o uso dela e a correção da descrição no `agenor-common` e no `modelo-de-dados.md` ficam para a A1.16.
- **Fundação ✅:** `get_session` (a transação é do serviço; o `get_db` herdado fica sem uso no app), `app/repositories/coleta.py` e o pacote `app/services/orchestration/`.
- **A1.11 ✅:** catálogo fechado `EventName` (os 8 eventos do modelo) e `record_event` (autor fixo por evento, salvo o `attempt.finished`; `attempt.*` exige `attempt_id`; `metadata` convertido para JSON; o evento entra na transação da mudança). O `modelo-de-dados.md` registra o catálogo como fechado.
- **`revisor-isolamento-banco`: ISOLADO.** Achados corrigidos: a chave `reason` do `attempt.created` e a redação de quando sai o `attempt.finished`, alinhadas entre código e documento. Observação acatada: a trava da coleta passou de `FOR UPDATE` para `FOR NO KEY UPDATE`, que serializa as transições da mesma coleta sem bloquear quem só insere itens ou eventos dela (a checagem da FK pede `FOR KEY SHARE`); ADR-004, `modelo-de-dados.md` e `AGENTS.md` do DC ajustados, com teste.
- **Testes:** 435 passam e 3 são pulados no DC.

- **A1.5 ✅:** `input`, `start`, `heartbeat` e `finish` (`app/services/orchestration/attempts.py`), com a regra de vigente e ativa da decisão 4.
  - `start` e `finish` travam a coleta antes (`lock_attempt`). O `heartbeat` só faz um UPDATE condicional na tentativa e, se ela foi encerrada no meio, responde com o status final.
  - Repetir `start` ou o mesmo `finish` responde 200 sem novo evento. Outro resultado depois do fim recebe 409 `ATTEMPT_NOT_CURRENT`; `CANCELLED` sem cancelamento, 409 `CANCEL_NOT_REQUESTED` (código novo, descrito no `openapi-v2.json` regerado).
  - O fim ainda não cria retentativa nem recalcula o status: entra na A1.7 e na A1.9.
- **`get_session` mudou de lugar:** foi para `app/routers/v2/session.py`, importando o `app.database` na chamada (como o `Settings` no `app/auth.py`). No `app/database.py`, o import exigia o `Settings` e o `scripts/exportar_openapi_v2.py` deixava de rodar sem configuração. **Incidente:** nessa falha, o erro de validação do pydantic imprimiu valores do `.env` do DC na saída do comando, inclusive uma senha. O `.env` não foi aberto e o valor não foi repetido nem usado. O Lucas foi avisado.
- **`revisor-isolamento-banco`: ISOLADO.** Achados corrigidos: a resposta do `heartbeat` no meio de um fim (com teste de concorrência) e o `scalar_one()` no `lock_attempt`. **Aviso para a A1.10:** a varredura e o `infra-event` precisam entrar por `lock_attempt` ou `lock_collection` antes de tocar a tentativa. Um `SELECT attempt … FOR UPDATE` seguido da trava da coleta inverte a ordem e abre deadlock com o `finish`. O `heartbeat` deve continuar com uma trava só.
- **Testes:** 450 passam e 3 são pulados no DC.

- **Pausa (decisão do Lucas, 29/10):** a #341 para depois da A1.5, com commit do que está pronto, para definir os padrões de código e desenvolvimento antes de seguir.

**Próximo:** padrões de código e desenvolvimento; depois, a #341 retoma pela A1.6 (itens idempotentes e itens já concluídos).

### Desenvolvimento, 29/10: padrões de código e desenvolvimento

- **Por que entrou:** o projeto tinha padrão de arquitetura (os ADRs, com os padrões do Agnes Collector) e de ferramentas, mas não de código nem de trabalho. O DC seguia em parte a estrutura herdada do DC atual e em parte o que cada sessão decidia. O levantamento mostrou:
  - nomes misturados: `repositories/coleta.py`, `establishment_repository.py`, `health_router.py`;
  - duas formas de abrir sessão no banco: o `get_db` e o `UnitOfWork` herdados e o `get_session` novo;
  - segredos em `str` (foi o que deixou o erro do pydantic imprimir o `.env` na A1.5) e dois jeitos de logar;
  - `ruff` só com as regras padrão e nenhuma checagem de tipos. Com as regras novas, 97 achados no DC e nenhum nos outros; o `mypy` achou 257 erros no DC (quase todos nos schemas herdados e cerca de 10 no código novo, um deles um retorno que podia ser `None`) e 5 no `agenor-common`.
- **Documentos (aprovados pelo Lucas em 29/10):** `docs/arquitetura/visao-geral.md` (as peças, uma coleta de ponta a ponta e qual documento manda em cada assunto), `docs/arquitetura/padroes-de-codigo.md` e `docs/padroes-de-desenvolvimento.md` (sequência da atividade, pronto quando, documentação, Git, revisão, dependências e segurança). O `AGENTS.md` da raiz e o de cada repositório apontam para eles.
- **Decisões, com a recomendação aceita:**
  1. Organização por camada (rota → serviço → repositório → modelo, mais `clients/`), não por domínio: é o padrão mais usado em FastAPI e basta para o tamanho do projeto. Nada de hexagonal, DDD, repositório genérico, contêiner de injeção ou unit of work próprio.
  2. Logs com `logging` da biblioteca padrão; a saída em JSON fica para a A1.14, e o `loguru` herdado sai quando cada arquivo for tocado. Até a A1.14, os logs de `logging` em nível INFO não aparecem (só o `loguru` está configurado).
  3. `mypy` no `verify.sh` de todos os repositórios, com o plugin do pydantic; o herdado que não passa fica em `[[tool.mypy.overrides]]`, com o motivo.
  4. `ruff` com `E`, `W`, `F`, `I`, `B`, `UP`, `SIM`, `RUF`, `PT`, `ASYNC` e `C4`; o `E501` fica de fora porque o `ruff format` cuida do comprimento do código.
  5. Workers podem ser síncronos (uma tentativa por processo, código portado síncrono); DC e Launcher são assíncronos.
- **Aplicação:**
  - **DC, renomeações (commit separado):** `connectors/` → `clients/` (com `storage.py` e `storage_boto3.py`), `app/queue.py` → `clients/queue.py`, `repositories/coleta.py` → `collection.py`, `establishment_repository.py` → `repositories/establishment.py`, `establishment_service.py` → `services/establishment.py`, `health_router.py` → `routers/health.py`, e os testes no formato `test_<camada>_<módulo>.py`.
  - **DC, comportamento:** uma só sessão de banco (`app/database.py` com `get_session`, criada na primeira chamada; saíram o `get_db`, o `UnitOfWork` e o `routers/v2/session.py`). O `pool_reset_on_return="commit"` herdado também saiu: com a transação no serviço, o padrão do SQLAlchemy (rollback) é o certo. Segredos em `SecretStr` com `hide_input_in_errors`, com teste de que o erro não mostra o valor. Os achados do `ruff` e do `mypy` no código novo corrigidos (o `_load` da tentativa passou a usar `session.get_one`); o herdado ficou nas exceções do `pyproject.toml`, cada uma com o motivo.
  - **`agenor-common`:** os 5 erros de tipo (`create_queue` passa os campos obrigatórios por `_required`).
  - **Launcher e workers:** `settings.py` → `config.py`, `hide_input_in_errors`, rotas assíncronas no Launcher e `attempt_id`/`collected_id` como UUID no worker.
- **Testes:** DC 447 passam e 3 são pulados (saíram os 7 testes do `get_db` e do `UnitOfWork`, entraram 4); `agenor-common` 46; Launcher 2; workers 2.
- **`revisor-isolamento-banco`: ISOLADO.** Os engines do DC v2 e do company-service ficam separados, toda transação desfaz no erro, e a URL do Alembic usa a senha real do `SecretStr`. Achados menores, todos herdados e fora do isolamento, ficam para quando o código for tocado:
  - a senha entra na URL por f-string, sem escapar (`URL.create` resolve);
  - o engine de filiais não é fechado no shutdown e herda o pool do v2 (até 50 conexões para um banco só de leitura);
  - o `except Exception` do repositório de filiais devolve lista vazia em qualquer falha;
  - o `Establishment` não tem schema, e só é seguro porque a URL de filiais é a do company-service.

  Os três últimos entram na A1.16, quando a API do consumidor usar as filiais; o primeiro, na A1.14, com a configuração.

**Próximo:** a #341 retoma pela A1.6 (itens idempotentes e itens já concluídos), no padrão de código.

### Desenvolvimento, 29/10: padrões de projeto e adequação do que já existe

- **Pedido do Lucas:** além do padrão de código, uma base de construção definida com padrões de projeto (GoF: criacionais, estruturais e comportamentais), padrões arquiteturais e SOLID. Não um retrato do que usamos ou não, e sim **qual padrão usar para cada problema**, na forma do projeto.
- **Documento:** `docs/arquitetura/padroes-de-projeto.md` (proposta), com:
  - uma tabela de decisão ("preciso de… → padrão");
  - 11 regras arquiteturais com o ADR de cada uma;
  - os padrões de projeto, cada um com quando usar, a forma no projeto, um trecho modelo e a referência no código: Factory Method, Singleton de módulo, Adapter, Facade, Repository, Decorator, Strategy em registro por enum, Template Method, State como tabela de transições, Command, Observer com tabela de tratadores, Chain of Responsibility e Factory de teste;
  - o SOLID como regras obrigatórias, com o que a revisão confere, mais KISS, YAGNI e DRY.
- **Decisão do Lucas:** antes de seguir a #341, analisar o que já foi construído e pôr no padrão. Seguir e voltar depois custa mais.
- **Análise (29/10), nos quatro repositórios:**
  - **Fora do padrão, no código novo (ajustar agora):**
    1. *State:* o `start` e o `finish` mudam `attempt.status` direto; falta a tabela de transições com a função `transition` e o teste de cada transição.
    2. *Factory Method:* o `create_queue` usa `if`; o padrão é `match` no enum.
    3. *Singleton:* `app/clients/queue.py` guarda a fila numa variável global; o padrão é `@cache`, com `cache_clear` no fechamento.
    4. *Factory de teste:* três funções `_collection` repetidas nos testes; vão para `tests/factories.py`.
    5. *Nomes:* cerca de 30 testes com nome em português (os da orquestração e alguns herdados de CNPJ) e três scripts (`exportar_openapi_v2.py`, `sondar_token_agnaldo.py`, `exportar_contrato.py`); identificador é em inglês.
    6. *Docstring do padrão:* os adaptadores de fila, o `create_queue`, o `JwksKeyProvider` e os serviços não dizem o padrão que implementam.
  - **Ajustes no próprio padrão de código**, porque o código mostra casos que ele não previa: `utils/` para funções puras sem I/O (validação de CNPJ); `models/` com um módulo por schema (`agenor_coleta.py`); `Any` também para objeto de biblioteca sem tipos (o cliente da OCI).
  - **Herdado, já com a atividade em que entra no padrão** (exceções registradas no `pyproject.toml`):
    - `app/main.py` (`loguru`, imports depois de código, middleware do Ledger, `domains/billing`), na A1.14;
    - os schemas do consumidor (a cadeia de `if collection_type == ...` em `unified.py` vira registro por enum), `app/dependencies.py` (`X-User-ID`), os clientes do bucket (sem `Protocol`, com `loguru`) e o repositório e o serviço de filiais (classe e `except Exception`), na A1.16.
  - **Sem achado:** nenhum `os.environ` fora da configuração, nenhum `HTTPException` em serviço ou repositório, nenhum SQL em rota, os adaptadores de fila já convertem os erros da biblioteca nos nossos, e o Launcher e os workers estão no padrão.

- **Overengineering? (pergunta do Lucas):** não. A tabela de transições impede, por exemplo, que um aviso atrasado reabra uma tentativa encerrada; sem ela, a regra fica espalhada em `if`s a cada atividade (A1.7, A1.9, A1.10). O Adapter atrás de `Protocol` permite testar sem a OCI; Strategy e Template Method fazem de um coletor novo só um pacote novo. O padrão proíbe o que seria excesso: hierarquia de classes por padrão, contêiner de injeção, unit of work próprio. O item de menor valor (docstring com o nome do padrão) ficou numa linha, só onde ajuda.
- **Padrão de projeto aprovado e adequação aplicada (29/10):**
  1. *State:* `app/services/orchestration/states.py` com `ATTEMPT_TRANSITIONS` e `transition_attempt`; o `start` e o `finish` passam por ela. O `RUNNING` direto do `QUEUED` é permitido porque o `start` do worker pode chegar antes do `JOB_CREATED`. Os erros de domínio foram para `errors.py`. 81 casos de teste, um por par de status.
  2. *Factory Method:* `create_queue` com `match`.
  3. *Singleton:* `app/clients/queue.py` com `@cache`; o `close_queue` limpa o cache.
  4. *Factory de teste:* `tests/factories.py` no DC.
  5. *Nomes:* 42 testes renomeados para o inglês; scripts `export_openapi_v2.py`, `probe_agnaldo_token.py` (com as variáveis) e `export_contract.py`.
  6. *Docstring do padrão:* adaptadores de fila, `JwksKeyProvider`, repositório e serviço de tentativas.
  - No padrão de código: `utils/` para funções puras, `models/` com um módulo por schema, `scripts/` com nome em inglês e `Any` também para objeto de biblioteca sem tipos.
- **Testes:** DC 531 passam e 3 são pulados; `agenor-common` 46.
- **`revisor-isolamento-banco`: ISOLADO.** O ADR-002 passou a registrar os atalhos da tabela (`QUEUED → RUNNING`; qualquer status vigente para um final; de um final não se sai). **Decisão aberta para o Lucas:** hoje o `finish` do worker é aceito com a tentativa ainda em `QUEUED` ou `STARTING`, sem `start` (comportamento da A1.5, e os testes usam esse caminho). A recomendação é aceitar o resultado do worker só depois do `start`, salvo o `CANCELLED`; decidir antes da A1.6.

**Próximo:** a #341 retoma pela A1.6 (itens idempotentes e itens já concluídos), no padrão de código e de projeto.
