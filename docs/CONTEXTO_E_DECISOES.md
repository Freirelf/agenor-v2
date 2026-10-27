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
