# Agenor 2.0: plano

Documento de trabalho, construído em etapas. Cada etapa é validada antes da seguinte, e qualquer uma pode ser revisitada.

1. **Visão:** o que vamos fazer. ✅ validada em 26/10
2. **Papel de cada componente.** ✅ validada em 26/10 (inicialmente)
3. **Planejamento técnico e pedidos de infra.** ✅ validada em 26/10
4. **Roadmap:** fases, marcos e ordem de construção. ✅ validada em 26/10
5. **Documento base e apresentação** ✅ primeira versão em 26/10:
   - documento: https://claude.ai/artifact/5i1RR8SQi4BdQ1abBdKavK
   - slides: https://claude.ai/artifact/619LxnSFfushYgKdLhiqJZ
   - ambos privados até serem compartilhados; este arquivo continua sendo a fonte de trabalho
6. **Atividades.** ✅ primeira versão escrita (antecipada para entrar no documento base)

**Refinamento (iniciado em 26/10):**

- revisão das etapas 1 a 4 ✅ concluída em 26/10;
- revisão item a item das atividades do alicerce (fases 0 a 2) ✅ concluída em 27/10; as fases 3 a 6 ficam no nível atual e são detalhadas na vez de cada uma;
- prazos do alicerce ✅ definidos em 27/10 (§6): M0 em 29/10 e M1 em 13/11 (18/11 com folga), acompanhados no Squads;
- documento base e slides atualizados com o refinamento: pendente.

**Por etapas (decidido em 27/10):** o foco é o alicerce. Cada processo (coletor, extração, planilhas) é detalhado, validado e ajustado na sua vez. Diretriz da extração: parsers e planilhas reaproveitados, JSON no bucket, e tabelas e consultas depois (§3.5).

**Produto novo (decidido em 27/10):** o 2.0 é a reconstrução do Agenor numa nova sistemática, em repositório e schema próprios (`agenor_coleta`). Reaproveita processos do sistema atual, não a estrutura. O destino do sistema atual é decisão do cliente.

**Infra é do cliente (decidido em 27/10 e 28/10):** não alteramos pipelines, Sonar, `helm/`, `kubernetes/` nem values; problemas neles viram alerta. **Não escrevemos chart nem values.** O DC v2 e o Launcher sobem no kind com manifestos simples em `local/` (nossos e só locais), e a migração roda como um Job local. Para o cliente vai o `infra.md`; chart, values, pipeline e deploy dos ambientes são dele.

**Local primeiro (decidido em 26/10):** tudo é validado e testado no ambiente local; os ambientes são a última etapa (§4).

**Nível de detalhe (decidido em 26/10):** o plano guarda o que muda escopo, ordem, prazo, infra ou risco, e as decisões estruturais em uma linha cada. O detalhe técnico (modelo de dados, contratos, status, despachante, autenticação) vai para os ADRs da A0.6, em `agenor-v2/docs/arquitetura/`. A §3 é a matéria-prima desses ADRs e, depois deles, vira um resumo com links.

Depois do refinamento, desenvolvimento.

**Desenvolvimento (iniciado em 27/10):** #337 (A0.1 a A0.3) ✅ concluída em 27/10. `agenor-v2` criado com o código exportado, `ORIGEM.md` por projeto, senha do banco do company-service removida dos values, esqueletos do Launcher e dos workers e o `agenor-common` (evento da fila e interface de fila). #338 (A0.6) ✅ concluída em 27/10: nove ADRs e o `infra.md` em `docs/arquitetura/`, e as §3.1 a §3.9 resumidas com links. #339 (A0.4 e A0.5) ✅ concluída em 27/10: testes herdados do DC passando e ambiente local em `local/` (Postgres, S3 local, DC atual e cluster kind). **M0 atingido em 27/10.** O CI ficou fora: pipelines são infra do cliente. #340 (A1.1 a A1.4, A1.13, A1.17: DC 2.0, base) ✅ concluída em 28/10: contrato da API v2 e retrato do contrato do consumidor, validação do token do Agnaldo pelo JWKS do SSO, migrações no `agenor_coleta`, imagem com migração separada e DC v2 no compose e no kind, DC v2 limpo do que não é do 2.0 e interface de fila com adaptadores em memória, local (Postgres) e OCI. O `ruff` foi adotado no DC v2 num commit só de formatação. **Modelagem de dados do `agenor_coleta` (A1.3b) ✅ concluída em 29/10:** a A1.3 tinha ido da lista de tabelas do ADR-002 direto para a migração. O schema passou a se chamar `agenor_coleta` (era `agenor_v2`; a pasta de trabalho continua `agenor-v2`). O `docs/arquitetura/modelo-de-dados.md` (aprovado pelo Lucas) descreve cada tabela e coluna; o modelo e a migração inicial foram refeitos a partir dele, os ADR-002, 004 e 007 atualizados, e o harness passou a exigir o documento antes de qualquer migração. #341 (A1.5 a A1.11: DC 2.0, orquestração) em andamento desde 29/10: plano de execução aprovado pelo Lucas (ordem fundação, A1.11, A1.5, A1.6, A1.7, A1.9, A1.8, A1.10, e as 6 decisões no `CONTEXTO_E_DECISOES.md`); fundação, A1.11 e A1.5 ✅. Pausada em 29/10 (decisão do Lucas) para definir os padrões de código e desenvolvimento. **Padrões de código e desenvolvimento ✅ concluídos em 29/10:** `docs/arquitetura/visao-geral.md`, `docs/arquitetura/padroes-de-codigo.md` e `docs/padroes-de-desenvolvimento.md`, aprovados pelo Lucas e aplicados nos quatro repositórios de código (`ruff` ampliado e `mypy` no `verify.sh`; no DC, renomeações, uma só sessão de banco e segredos em `SecretStr`). **Padrões de projeto, arquiteturais e SOLID ✅ 29/10** (`docs/arquitetura/padroes-de-projeto.md`, aprovado pelo Lucas), com o código já construído adequado no mesmo dia (tabela de transições da tentativa, Factory Method e Singleton da fila, factories de teste, nomes em inglês). Próxima: a #341 retoma pela A1.6, já no padrão.

**Documentos de trabalho (27/10):** este plano, o `CONTEXTO_E_DECISOES.md`, o relatório de diagnóstico e os documentos do cliente (`cliente/`) passaram a ser versionados em `agenor-v2/docs/`, no repositório de docs. Os entregáveis continuam em `ag-capital/agenor/entregaveis/`.

**Estado herdado do DC (27/10):** dos testes atuais, 560 passam, 54 falham e 109 dão erro (o `Settings` exige variáveis de ambiente no import, e um teste importa um módulo removido). O `black` e o `isort` herdados não passam, e não há `ruff`. Os testes entraram na A0.4 ✅ (27/10): 715 passam e 2 são pulados. O `ruff` (lint e formatação) entrou no fim da A1.13 ✅ (28/10), num commit só de formatação: desde então, as mudanças da origem deixam de entrar por diff e passam a ser portadas à mão.

**Estrutura de repositórios (27/10):** o `agenor-v2` virou uma pasta de trabalho com quatro repositórios separados (`agenor-document-collector`, `agenor-launcher`, `agenor-workers`, `agenor-common`), um repositório de docs e a `referencia/` fora do Git (§4, fase 0). **Hospedagem (27/10):** cada repositório terá dois remotos, o GitHub da Solfy para o nosso time e o Bitbucket do cliente. ✅ Os cinco subiram para o GitHub em 27/10 (`origin`); o Bitbucket do cliente entra depois.

**Padrões (29/10):** a arquitetura está resumida em [visao-geral.md](arquitetura/visao-geral.md), o código segue [padroes-de-codigo.md](arquitetura/padroes-de-codigo.md) e o trabalho segue [padroes-de-desenvolvimento.md](padroes-de-desenvolvimento.md). Valem para todo o projeto; o código herdado entra no padrão quando for tocado.

**Harness de desenvolvimento ✅ concluído em 27/10:** `AGENTS.md` na raiz do `agenor-v2` (contexto entre repositórios) e um em cada repositório (comandos e armadilhas dele), `scripts/agent/verify.sh` por repositório e um na raiz, `.claude/` (settings, hooks) só na raiz e o subagente revisor do isolamento do banco. O hook de bloqueio foi testado com 31 casos, e o `verify.sh` da raiz reporta o estado real (desde a A0.4, os quatro repositórios passam). Como validar: `AGENTS.md` da raiz, seção "Verificação". Componentes que só entram quando o procedimento existir:

- ~~**skill "nova migração no `agenor_coleta`"**~~ ✅ 28/10 (`.claude/skills/nova-migracao-agenor-coleta/`), a partir da A1.3;
- **skill "portar um coletor":** ao concluir o piloto Fontes Pagadoras (A3.10, M2);
- **`docs/agent/`:** só se surgir contexto que os ADRs não cubram.

---

## 1. Visão

### O que é o Agenor

Plataforma que coleta documentos e dados fiscais federais das empresas clientes da AG Capital. A coleta é feita nos portais da Receita (e-CAC, DCTFWeb, PagtoWeb e outros), com o certificado de um procurador.

### O que vamos fazer

**Reconstruir o produto Agenor numa nova sistemática**, em repositório próprio (`agenor-v2`): alicerce, arquitetura, segurança e padrões de desenvolvimento definidos por nós. Do sistema atual, reaproveitamos o que é processo: os fluxos nos portais, as regras fiscais, os parsers e a integração com o Agnaldo. Não reaproveitamos a estrutura.

O sistema atual não é alterado. Ele continua como está enquanto o cliente precisar dele, e o destino dele, inclusive o uso pelo AGuiar, é decisão do cliente. O 2.0 não depende dessa decisão.

**O centro da mudança é o modelo de execução das coletas.**

- **Hoje:** um único worker (o scraper) fica sempre ligado com 6 réplicas, consome a fila e executa todos os tipos de coleta.
- **No 2.0:** um **Launcher** consome a fila e sobe um **pod do worker do tipo de coleta**. O pod lê a entrada, coleta, guarda e é derrubado ao terminar, no modelo de uma função Lambda.

Junto com essa mudança, corrigimos os problemas que o diagnóstico encontrou no caminho da coleta. A nova arquitetura não deve herdá-los.

### Por que

- **Isolamento:** falha, deploy ou mudança em um tipo de coleta não afeta os outros.
- **Recursos sob demanda:** só há pod rodando quando há coleta. Cada tipo usa a imagem e os recursos de que precisa; Selenium só onde for necessário.
- **Evolução:** um tipo novo, como o eSocial, vira um worker novo, sem mexer nos existentes.
- **Manutenção:** os coletores deixam de ser monólitos (o DCTFWeb tem quase 3 mil linhas num arquivo) e passam a compartilhar uma base comum de sessão, status e armazenamento.

### Fluxo

```
Front → Agnaldo → Document Collector → fila → Launcher → pod do worker (por tipo)
                                                              │
                                        bucket (arquivos) ◀───┤
                                Document Collector (status) ◀─┘
```

### O que muda em cada parte

| Parte              | Hoje                                                                    | No 2.0                                                                                                                                                                 |
| ------------------ | ----------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Front              | Existe só em STG/DEV                                                    | Fora desta fase                                                                                                                                                        |
| Document Collector | Núcleo: registra, publica, recebe callbacks, guarda extrações, gera ZIP | **DC v2** em release própria, no mesmo banco: orquestrador que recebe a solicitação, registra, manda executar e acompanha o status. O DC atual continua no ar, intacto |
| Fila               | OCI Queue consumida pelo scraper                                        | OCI Queue consumida pelo Launcher                                                                                                                                      |
| **Launcher**       | Não existe                                                              | **Novo, desenvolvido por nós**                                                                                                                                         |
| Workers            | Scraper único com todos os tipos                                        | Um worker por tipo, em três etapas: ler, coletar, guardar                                                                                                              |
| Dados extraídos    | Tabelas por tipo no Document Collector                                  | Nesta versão, só em JSON no bucket, ao lado do arquivo. Tabelas no banco, consulta e histórico ficam para depois (§3.5)                                                |
| Agnaldo            | Sessões e-CAC, certificados, gateway                                    | Mantido; integração via API, sem alteração                                                                                                                             |

### Tipos de coleta

**Todos os tipos que o Agenor coleta hoje** passam para o modelo de workers. O **eSocial** já existe em outro produto, o Agnes Collector, e fica fora desta fase (§3.12). O desenho apresentado pelo cliente (6 workers) é um exemplo de demonstração, não a lista fechada. Os tipos do AGuiar que passam pelo Document Collector (intimações, despacho decisório, e-Processo) não entram.

Cada tipo vira um worker, sobre uma base comum (§3.6).

### Fora do escopo

- **Front:** fica para depois. Esta fase constrói o alicerce: Document Collector, fila, Launcher e workers.
- **Infraestrutura** (cluster, filas, buckets, pipelines, segredos): responsabilidade do cliente. Nós listamos o que precisamos e pedimos.
- **Agnaldo:** usamos a API, não alteramos o serviço.
- **AGuiar:** usa o mesmo Document Collector. Não é reformulado, mas **não pode quebrar**.
- **Regras fiscais e parsers:** são reaproveitados do código atual, não reescritos.

### Princípios

1. **Produto novo sobre processos existentes:** repositório `agenor-v2`, estrutura nova nos padrões do Agnes Collector, reaproveitando os processos do código atual (fluxos, regras fiscais, parsers).
2. Decisões técnicas são nossas.
3. **Construir a versão nova completa, sem convivência tipo a tipo com o scraper.** Como o modelo de dados também muda, manter os dois caminhos em paralelo custaria mais do que ajuda. **O 2.0 sobe como versão nova, ao lado da atual, que não é removida nem alterada.** A virada para produção está na §3.9: validação em STG e a versão atual intacta como plano de volta.
4. **Segurança faz parte da arquitetura**, não é ajuste posterior. O caminho novo nasce sem os riscos críticos do diagnóstico:
   - chamadas entre serviços sem autenticação;
   - consulta SQL livre no banco;
   - coletas paradas em `WAITING_SESSION` sem retomada.

### Como saberemos que terminou

- Todos os tipos no escopo rodam por Launcher e worker, com resultado equivalente ao de hoje.
- Toda coleta termina com status final ou entra em retentativa; nenhuma fica parada sem dono.
- A versão atual (scraper) é desligada após a virada.

### Validações

26/10: front fora desta fase; todos os tipos atuais (eSocial fora desta fase); versão nova completa, sem transição tipo a tipo; segurança dentro da arquitetura.

26/10 (refinamento): o 2.0 sobe em release própria ao lado da versão atual, no mesmo banco; a versão atual não é removida.

---

## 2. Papel de cada componente

Esta etapa define **o que cada parte faz e o que não faz**. Como cada uma faz (tecnologia, contratos, formatos) fica para a etapa 3.

### Visão geral

```
                 ┌──────────────────── Document Collector ────────────────────┐
 solicitação ──▶ │ registra · decide o que executar · dono do status e da      │
 (API)           │ retentativa · disponibiliza o resultado                     │
                 └───────┬──────────────────────────────────────▲─────────────┘
                         │ pedido de execução                    │ status e resultado
                         ▼                                       │ (worker e Launcher)
                       fila                                      │
                         │                                       │
                         ▼                                       │
                     Launcher ── cria e acompanha ──▶ pod do worker (por tipo)
                                                       ler · coletar · guardar
                                                          │            │
                                                     Agnaldo        bucket
                                                (sessão e-CAC)    (arquivos)
```

### Document Collector: orquestrador

**Faz:**

- Recebe as solicitações de coleta pela API, de qualquer consumidor (front no futuro, Agnaldo, integrações).
- Valida e registra a coleta. É o **único dono do estado**: o que foi pedido, em que status está, o histórico e o resultado.
- Decide o que executar, quanto e quando (capacidade por tipo), e publica o pedido na fila.
- Recebe o andamento e o resultado vindos dos workers, e as falhas de pod vindas do Launcher.
- **Decide a retentativa:** quando tentar de novo, quantas vezes e quando desistir, inclusive para coletas sem sessão e-CAC disponível.
- Disponibiliza o resultado: status e arquivos. Os dados extraídos ficam em JSON no bucket nesta versão.

**Não faz:**

- Não coleta e não fala com os portais da Receita.
- Não cria nem gerencia pods.
- Não expõe consulta SQL livre.

**Restrição:** o DC v2 roda em release própria e atende só o Agenor 2.0. O DC atual continua no ar para o AGuiar e para o scraper. Os dois compartilham o banco, e o v2 não pode quebrar o atual.

### Fila: transporte do pedido

**Faz:** leva o pedido de execução do Document Collector ao Launcher, desacoplando os dois. Se o Launcher estiver fora do ar ou no limite, o pedido espera na fila.

**Não faz:** não guarda estado da coleta e não é o mecanismo de retentativa. Quem decide tentar de novo é o Document Collector.

### Launcher: quem põe o worker para rodar

**Faz:**

- Consome os pedidos da fila.
- Identifica qual worker atende o tipo de coleta.
- Cria o pod do worker e entrega a entrada da execução.
- Mantém um **teto de segurança** de pods no cluster. Quantas coletas rodam, no total e por tipo, quem decide é o Document Collector.
- Acompanha o pod até o fim e garante que ele seja derrubado.
- Avisa o Document Collector quando o pod falha sem conseguir reportar: não subiu, travou, estourou o tempo ou a memória.

**Não faz:**

- Não coleta e não conhece regra fiscal.
- Não decide retentativa: só informa a falha.
- Não guarda dados de coleta.

### Worker: quem coleta (um por tipo)

**Faz, em três etapas:**

1. **Ler:** recebe do Launcher só os identificadores e busca a entrada completa no Document Collector.
2. **Coletar:** obtém a sessão e-CAC no Agnaldo, troca para o perfil do cliente e coleta os documentos e dados no portal. Aplica as regras fiscais do tipo.
3. **Guardar:** grava no bucket os arquivos e o JSON da extração, e entrega ao Document Collector o status e o resultado.

Termina ao fim da execução, com sucesso ou falha.

**Não faz:**

- Não consome a fila.
- Não acessa o banco: tudo passa pelo Document Collector.
- Não decide retentativa nem mantém estado entre execuções.

### Base comum dos workers

Tudo que hoje se repete em cada coletor do scraper vira uma base compartilhada por todos os workers:

- leitura da entrada;
- sessão e troca de perfil no Agnaldo;
- comunicação de status com o Document Collector;
- gravação no bucket com nomes determinísticos;
- proteção contra execução duplicada;
- erros tipados;
- logs e métricas.

Cada worker fica só com o que é específico do seu tipo: o fluxo no portal, as regras fiscais e os parsers.

### Serviços que usamos e não alteramos

| Serviço                         | Papel para o Agenor 2.0                                                                                  |
| ------------------------------- | -------------------------------------------------------------------------------------------------------- |
| **Agnaldo**                     | Fornece a sessão e-CAC do procurador, os certificados e o acesso ao SERPRO. Usado pelos workers via API. |
| **Bucket (OCI Object Storage)** | Guarda os arquivos coletados.                                                                            |
| **Banco (PostgreSQL)**          | Guarda o estado e os dados das coletas. Acessado só pelo Document Collector.                             |

### Cliente (infraestrutura)

Fornece e opera o cluster, a fila, o bucket, o banco, os segredos e os pipelines. Inclui **a permissão para o Launcher criar pods no cluster**. A lista completa de pedidos sai na etapa 3.

### Quem fala com quem

| De → para                            | Para quê                                                      |
| ------------------------------------ | ------------------------------------------------------------- |
| Consumidor → Document Collector      | Solicitar coleta, consultar status e resultado                |
| Document Collector → fila → Launcher | Pedido de execução                                            |
| Launcher → cluster                   | Criar, acompanhar e derrubar o pod                            |
| Launcher → Document Collector        | Avisar falha de pod                                           |
| Worker → Agnaldo                     | Sessão e-CAC, certificado, SERPRO                             |
| Worker → portais da Receita          | Coleta                                                        |
| Worker → bucket                      | Gravar arquivos                                               |
| Worker → Document Collector          | Ler a entrada da execução; informar status, resultado e dados |

**Toda chamada entre serviços é autenticada** (princípio 4 da Visão).

### Uma coleta, passo a passo

1. O consumidor solicita a coleta ao Document Collector, que registra e, quando houver vaga para o tipo, publica o pedido na fila.
2. O Launcher consome o pedido. Se o cluster estiver no teto de segurança, a mensagem volta para a fila.
3. O Launcher cria o pod do worker do tipo.
4. O worker lê a entrada, coleta e guarda. Informa o status e o resultado ao Document Collector.
5. O pod termina e o Launcher garante que ele seja derrubado.
6. **Se der errado:**
   - o worker falhou e conseguiu reportar → o worker informa o motivo;
   - o pod caiu, travou ou estourou o tempo → o Launcher informa;
   - em ambos os casos, o Document Collector decide se tenta de novo ou encerra como falha.

### Validações

26/10 (inicialmente): o Document Collector é o único dono da retentativa; o Launcher e o worker só informam. O worker não acessa o banco. ~~O Launcher controla a concorrência, no total e por tipo.~~ Mudou na §3.12: a concorrência é decidida pelo DC, e o Launcher só mantém o teto de segurança.

---

## 3. Planejamento técnico

Decisões técnicas para cada componente, baseadas no código atual (`staging` do scraper `366304a` e do Document Collector `8d2212f`, levantados em 26/10).

**Desde 27/10 (A0.6), o detalhe técnico está nos ADRs e no `infra.md` de [`docs/arquitetura/`](arquitetura/README.md).** As §3.1 a §3.9 resumem cada decisão e apontam para o ADR. As §3.0 e §3.10 a §3.13 continuam aqui. Uma mudança de decisão técnica entra primeiro no ADR.

### 3.0 O que o código atual mostra e muda o desenho

| Fato                                                                                                                | Consequência para o 2.0                                                                                                                                                          |
| ------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| O scraper processa **uma coleta por réplica**; com 6 réplicas, no máximo 6 coletas simultâneas                      | O limite atual de paralelismo é 6. É o ponto de partida dos limites do Launcher                                                                                                  |
| Uma coleta pode durar horas (a mensagem é renovada na fila por até 4 h)                                             | Cada tipo precisa de um tempo máximo próprio                                                                                                                                     |
| Sem sessão e-CAC, o scraper **apaga a mensagem** e nada reenfileira                                                 | A retentativa precisa de um dono (já decidido: Document Collector)                                                                                                               |
| Sessão, troca de perfil, status e upload são **reescritos em cada coletor**                                         | Viram a base comum dos workers                                                                                                                                                   |
| Só **Créditos DCTFWeb usa Selenium** (Moon remoto); **DCTF usa Chrome local** para HTML→PDF; os demais são HTTP     | Duas imagens bastam: a padrão e uma com Chrome                                                                                                                                   |
| **DARF** usa outro serviço de sessão (session-manager) e um resolvedor de hCaptcha, além do Agnaldo e do SERPRO     | São dependências extras do worker DARF                                                                                                                                           |
| No Document Collector, o **status da coleta tem vários escritores**: o scraper grava direto e o DC também recalcula | O worker passa a só informar; quem calcula o status é o DC                                                                                                                       |
| O **ZIP é gerado dentro da requisição de callback**                                                                 | O ZIP sai da requisição e vira um job                                                                                                                                            |
| **Extrações são só inseridas**: uma nova tentativa duplica as linhas                                                | Nesta versão, a extração vai para um JSON no bucket com chave determinística: uma nova tentativa sobrescreve, não duplica                                                        |
| **Nenhum callback tem autenticação nem identificador de tentativa**                                                 | Contrato novo, autenticado e com tentativa                                                                                                                                       |
| O AGuiar usa as mesmas tabelas `collected` e `collection_execution` e os mesmos callbacks                           | O DC atual continua no ar para o AGuiar; o DC v2 roda em release própria, no mesmo banco, com uma API nova e no schema próprio `agenor_coleta`, sem escrever nas tabelas do DC atual |
| O DC atual roda `alembic upgrade head` toda vez que o pod sobe (`entrypoint.sh`)                                    | Se o v2 registrar migrações na mesma `alembic_version`, o DC atual não sobe mais no próximo restart. O v2 guarda a versão do Alembic dentro do schema `agenor_coleta`                |

### 3.1 Tentativa: a unidade de execução

Cada execução de uma coleta é uma tentativa, numa tabela própria do v2, com no máximo uma ativa por coleta. O worker só informa (itens e resultado), e o DC é o único dono do status da coleta, que mantém os valores de hoje. Sinal de vida a cada 1 min, com cancelamento. Os workers não dependem de Redis. **Detalhe:** [ADR-002](arquitetura/adr-002-tentativa-e-status.md).

### 3.2 Mensagens e contratos

Evento da fila só com identificadores (`version`, `type`, `collected_id`, `attempt_id`, `dispatched_at`); o worker busca a entrada completa no DC e descarta se a tentativa não for a vigente. API nova do worker e do Launcher no DC, autenticada por usuários de serviço do Agnaldo. API do consumidor com o mesmo contrato do DC atual. **Detalhe:** [ADR-003](arquitetura/adr-003-contratos.md) e [ADR-006](arquitetura/adr-006-autenticacao-por-usuario-de-servico-do-agnaldo.md).

### 3.3 Launcher

Serviço sem banco, com catálogo de tipos versionado. Um Kubernetes Job por tentativa, com nome determinístico e `backoffLimit: 0`; a mensagem é apagada depois que o Job é criado. Informa ao DC como cada Job terminou. Só mantém um teto de segurança; uma réplica no início. **Detalhe:** [ADR-005](arquitetura/adr-005-launcher-com-kubernetes-jobs.md).

### 3.4 Document Collector

- **Duas releases, um banco:** o DC v2 roda em release própria, isolado no schema `agenor_coleta`, com a `alembic_version` dentro dele e a migração numa etapa separada, antes do deploy. O DC atual continua intacto para o AGuiar e o scraper. **Detalhe:** [ADR-001](arquitetura/adr-001-isolamento-no-schema-agenor-coleta.md).
- **Despachante, retentativa e abandono:** a tabela de tentativas é a fila de verdade; o DC decide capacidade (6 no total, Créditos DCTFWeb até 4), retentativa (falha técnica até 3, separada da de negócio com espera de 5, 15, 30, 60 e 60 min) e abandono (5 min sem sinal de vida ou 60 min sem início). Sem Temporal nesta fase. **Detalhe:** [ADR-004](arquitetura/adr-004-despachante-e-retentativa.md).
- **Histórico de eventos** no formato do Agnes Collector e `status_text` legível ([ADR-002](arquitetura/adr-002-tentativa-e-status.md)). **ZIP** como worker; a ligação dele com a coleta no banco é decidida na fase 4 ([ADR-007](arquitetura/adr-007-workers-por-tipo-com-base-comum.md)). **Modelo de dados:** [modelo-de-dados.md](arquitetura/modelo-de-dados.md) (A1.3b).
- **O DC v2 nasce sem** `query_consult`, `/test-collected`, `/sentry-debug` público, CORS aberto, rotas antigas sobre o `public`, orquestrador, sweepers e consumo da fila antiga (A1.13).
- **Banco do company-service:** o acesso continua, com usuário somente leitura em Secret (pedido 11).

### 3.5 Dados extraídos

Detalhado por tipo quando cada coletor for portado (fase 4). Nesta versão, parsers e planilhas reaproveitados e a extração em JSON no bucket; tabelas, API de consulta e cópia do histórico ficam para depois. **Detalhe:** [ADR-007](arquitetura/adr-007-workers-por-tipo-com-base-comum.md).

### 3.6 Workers

Repositório `agenor-workers`, com `core/` (base comum que executa o fluxo) e um pacote por tipo em `workers/`. Duas imagens (padrão e com Chrome, só para o DCTF), chave única no bucket, erros tipados e configuração validada. Saem o DCTFWeb legado, o `fill_dctf_web`, o data-collector e o Redis. **Detalhe:** [ADR-007](arquitetura/adr-007-workers-por-tipo-com-base-comum.md).

### 3.7 Segurança

- Autenticação entre serviços por usuários de serviço do Agnaldo ([ADR-006](arquitetura/adr-006-autenticacao-por-usuario-de-servico-do-agnaldo.md)).
- Fim do SQL livre, dos endpoints de teste e do CORS aberto (§3.4).
- Nenhum dado fiscal ou pessoal na fila nem na definição dos Jobs ([ADR-003](arquitetura/adr-003-contratos.md)).
- Workers sem root; o Launcher só gerencia Jobs no namespace dos workers; saída de rede dos workers restrita ([infra.md](arquitetura/infra.md)).
- Segredos só em Secret, nunca em ConfigMap ou log. Sem `DEBUG_MODE` e sem vídeo do navegador em produção ([ADR-008](arquitetura/adr-008-observabilidade.md)).

### 3.8 Observabilidade

OTel para o Alloy, `/metrics` com ServiceMonitor no DC e no Launcher, métricas de negócio saindo do DC, logs em JSON com `collected_id` e `attempt_id`, e health checks reais. **Detalhe:** [ADR-008](arquitetura/adr-008-observabilidade.md).

### 3.9 Virada para produção

Local → DEV e STG (com comparação lado a lado em STG) → deploy em PRD ao lado da versão atual → virada única pelos consumidores → janela de volta → desligamento do scraper. Sem chave de ambiente. **Detalhe:** [ADR-009](arquitetura/adr-009-virada-unica-pelos-consumidores.md).

### 3.10 Pedidos ao cliente

**Parte A: para desenvolvimento e testes locais**

| #   | Pedido                                                                                                     | Quando                                                           |
| --- | ---------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| A1  | ~~Confirmar a branch de partida~~ Não é mais pedido: partimos da branch mais atual de cada projeto (27/10) | —                                                                |
| A2  | Procurador, certificado e CNPJs de teste                                                                   | Antes do piloto (fase 3); alinhado durante as fases 1 e 2 (A0.8) |
| A3  | Acesso aos proxies                                                                                         | Antes do piloto (fase 3); alinhado durante as fases 1 e 2 (A0.8) |
| A4  | Acesso de teste ao Moon, ao session-manager e ao hCaptcha                                                  | Antes de Créditos DCTFWeb e DARF (fase 4)                        |

**Já temos:** o esquema do banco (pelas migrações do código), os usuários de serviço do Agnaldo (os mesmos dos outros produtos; validado em 28/10 com o `solfy_coleta`) e o acesso aos repositórios. Fila e armazenamento rodam localmente.

**Parte B: infra dos ambientes (última etapa; alinhada no decorrer do desenvolvimento, não agora)**

| #   | Pedido                                                                                                                                                    | Para quê                                                         |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| 1   | Namespace dos workers, com ResourceQuota                                                                                                                  | Isolar e limitar os Jobs                                         |
| 2   | ServiceAccount e Role para o Launcher: criar, listar, observar e apagar Jobs e pods, e ler logs, **só nesse namespace**                                   | Launcher criar os pods                                           |
| 3   | Fila OCI nova para o 2.0 por ambiente: visibilidade de 15 min, retenção de 7 dias, 3 entregas, DLQ. Permissões: DC publica; Launcher lê, atualiza e apaga | Não colidir com a fila do scraper na virada                      |
| 4   | Repositórios no Harbor: `agenor-launcher`, `agenor-worker`, `agenor-worker-chrome`                                                                        | Imagens                                                          |
| 5   | Pipelines no Bitbucket, charts e values para os repositórios novos (DC v2, Launcher e workers), a partir do `infra.md`                                                                                | Build e deploy                                                   |
| 6   | Usuários de serviço no Agnaldo para o Launcher e os workers (o DC valida o token pelo JWKS do SSO e autoriza pelo nome do usuário, ADR-006)                | Autenticação entre serviços                                      |
| 7   | Secrets: chave de API da OCI (montada como arquivo), bucket, usuários de serviço do Agnaldo, proxies, session-manager, hCaptcha                           | Credenciais                                                      |
| 8   | Capacidade de nós (CPU e memória) para os picos de Jobs                                                                                                   | Execução                                                         |
| 9   | NetworkPolicies de saída dos workers                                                                                                                      | Segurança                                                        |
| 10  | Migrações do banco como etapa separada antes do deploy (um Job com o comando de migração da imagem; ex.: hook do Helm), não no start do pod                                                                                          | Deploy seguro                                                    |
| 11  | Usuário somente leitura no banco do company-service                                                                                                       | Substituir o superusuário                                        |
| 12  | Ambientes DEV e STG para as releases do 2.0                                                                                                               | Validação                                                        |
| 13  | ServiceMonitor para DC e Launcher, endpoint OTLP (Alloy) e coleta dos logs dos Jobs                                                                       | Observabilidade                                                  |
| 14  | Desligar o sweeper ativo da release `-apisix` do DC antes do 2.0 entrar em PRD                                                                            | Ele pode republicar coletas do v2 na fila antiga (§3.13, item 4) |

**Alertas ao cliente (não corrigimos, só avisamos):**

- rotacionar as credenciais expostas no histórico Git;
- sweeper ativo na release `-apisix` com código antigo;
- `DEBUG_MODE` e vídeo do Moon em PRD;
- superusuário do Postgres em ConfigMap;
- heads do Alembic divergentes entre a release principal e a `-apisix` do DC, com migração no start do pod (§3.13, item 7).
- o `bitbucket-pipelines.yml` do DC, que veio para o repositório do v2, faz build e deploy da release `document-collector-service` nos namespaces do DC atual e usa a chave do Sonar dele: antes de o v2 entrar no Bitbucket, o pipeline do v2 precisa de release, imagem e chave próprias (27/10).
- o mesmo pipeline faz `docker build .` sem o contexto do `agenor-common`, que a imagem do v2 exige enquanto não há tag Git publicada; e o chart herdado tem um CronJob que chama `app.routines.orchestrator_routines`, que não existe no v2. Os dois só servem ao DC atual (28/10).

### 3.11 Pendências

1. ~~Branch de partida~~ **Decidido em 27/10 com o time interno:** não esperamos o cliente. Na exportação (27/10), as branches mais recentes do DC (`refactor/Uow`) e do scraper (`dev`) tinham divergido da `staging`, sem funcionalidades já integradas nela. Por isso o DC e o scraper saíram da `staging` (8d2212f e 366304a) e o download service da `feat/service-zip` (94c5f37). Os commits só da `dev` do scraper entram por diff ao portar cada coletor. Detalhes no `ORIGEM.md` de cada projeto.
2. ~~As coletas do AGuiar continuam no Document Collector?~~ **Deixou de ser pergunta em 27/10.** O 2.0 é um produto novo, em schema próprio, e não depende do que o cliente fizer com o DC atual. O documento para o cliente informa a decisão em vez de perguntar.

**Descartadas em 26/10:**

- **Volumes e durações por tipo em PRD.** Começamos com os valores de hoje (6 coletas simultâneas, prazo de até 4 h) e calibramos com as métricas do próprio 2.0, primeiro no ambiente local e depois em STG.
- **Quem chama os `consult_*`.** Eles continuam na API antiga nesta fase (§3.5).

### 3.12 Padrões do Agnes Collector

**Referência:** `ag-capital/agnes-collector`, branch `feature/oci-queue` (`fca5e57`, 20/10). A documentação de lá (`docs/arquitetura/`: visão geral, ADR-001 a 003, fases 1 a 5, `infra.md`) é a base dos padrões abaixo.

**Linguagem:** o Agnes Collector é TypeScript/Node, e o Agenor continua em **Python**, porque as regras fiscais e os parsers que reaproveitamos estão em Python. Adotamos os padrões de arquitetura, contrato, infra e operação. O que é específico de TypeScript é traduzido:

| Agnes Collector (TypeScript) | Agenor (Python)        |
| ---------------------------- | ---------------------- |
| Drizzle                      | SQLAlchemy e Alembic   |
| `async-retry`                | tenacity               |
| `prom-client`                | prometheus_client      |
| `withAgentAuth`              | dependência do FastAPI |

**Adotados:**

| Padrão                                                                                                                                                                             | Onde no plano                                |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| O Collector (aqui, o DC) é dono de todo o estado; os workers só executam e informam por REST                                                                                       | §3.2, §3.4                                   |
| A tabela do banco é a fila de verdade; a OCI Queue só transporta o que está pronto; um despachante com lock e capacidade publica e só então marca como despachado                  | §3.4                                         |
| Evento enxuto e versionado; o worker busca a entrada pelo identificador e descarta se estiver obsoleta                                                                             | §3.2                                         |
| Sinal de vida a cada 1 min com cancelamento; abandono detectado pelo banco (5 min e 60 min), sem depender da DLQ                                                                   | §3.1, §3.4                                   |
| Falha técnica (até 3) separada da retentativa de negócio (5, 15, 30, 60, 60 min…)                                                                                                  | §3.4                                         |
| Integração com o Agnaldo: usuário de serviço → token; reservar sessão, manter ativa, trocar perfil e sempre devolver. Estendido por nós: o mesmo token autentica as chamadas ao DC | §3.2, §3.6                                   |
| Histórico de eventos com categoria, nome, autor e metadados, e `status_text` legível                                                                                               | §3.4                                         |
| ~~Chart Helm por serviço, values por cluster, migração como hook~~ Fica com o cliente (28/10): não escrevemos chart nem values; o `infra.md` diz o que o código precisa                                      | §3.4, §3.10                                  |
| Pipeline Bitbucket: Sonar e SBOM (Dependency-Track) em paralelo, build no Harbor com cache, `helm upgrade --install --wait`, PRD manual                                            | §3.10                                        |
| OTel para o Alloy, `/metrics` com ServiceMonitor                                                                                                                                   | §3.8                                         |
| Documentação em ADRs, por fase, e um `infra.md` com só o que o código precisa do ambiente                                                                                          | [`docs/arquitetura/`](arquitetura/README.md) |

**Não copiados (melhorados):**

- autenticação com `base64(agent_id)`;
- variáveis de ambiente sem validação;
- logs em texto livre;
- URLs de produção fixas no código;
- token do Agnaldo em arquivo no disco.

**Não adotados agora:**

- o Temporal, porque não há agendamento recorrente nesta fase (§3.4);
- o mecanismo novo atrás de uma chave de ambiente, porque o 2.0 roda em releases próprias e a versão atual não recebe código novo (§3.9).

**Mudanças em decisões já validadas (26/10):**

1. **A concorrência passa a ser decidida pelo Document Collector** (despachante), não pelo Launcher. O Launcher fica só com um teto de segurança do cluster. Com isso, não são necessários canais por tipo na fila. Aceita conforme as recomendações.
2. **A autenticação entre serviços passa a ser por usuários de serviço do Agnaldo**, não por clients no Keycloak. Precisa rever, quando for trabalhar vamos analisar como é, e se da certo, por que a troca? se o sistema utiliza Keycloak qual o motivo de mudar?.
3. **Duas releases no mesmo banco, em vez de chave de virada** (refinamento de 26/10). O DC v2 sobe ao lado do atual. Aprovada explicitamente. A `alembic_version_v2` da primeira versão foi substituída em 27/10 pelo schema `agenor_coleta`, com a `alembic_version` dentro dele ([ADR-001](arquitetura/adr-001-isolamento-no-schema-agenor-coleta.md)).

**eSocial:** o Agnes Collector **é** o coletor de eSocial (RPA com Puppeteer, sessões `sessao-esocial` do Agnaldo). Isso explica a caixa "eSocial Collector" no desenho do cliente. Fica fora desta fase, como combinado. A integração dele como mais um "motor" do Agenor entra depois.

### 3.13 Pontos de atenção

Lista única dos pontos que podem quebrar algo fora do Agenor 2.0 ou travar o plano. O maior é o **banco compartilhado**: com o modelo de duas releases, passam a escrever no mesmo Postgres de PRD (`hiperautomacao_document_collector_prd`):

- o **DC atual**, que atende o AGuiar, o scraper e a API antiga;
- o **DC v2**, que atende o Agenor 2.0;
- a release **`-apisix`** do DC, com código de 30/07 e o sweeper do orquestrador em modo **ativo**.

**Status:** **tratado** = o plano já resolve; **verificar** = precisa de confirmação no código ou no cluster na fase 1; **cliente** = depende do cliente.

**Banco compartilhado com o AGuiar e com as outras releases**

| #   | Ponto                                                                                                           | Por que importa                                                                                                                                                                                                     | Como tratamos                                                                                                                                                      | Status                   |
| --- | --------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------ |
| 1   | O AGuiar usa as mesmas tabelas (`collected`, `collection_execution`, eventos) e os mesmos callbacks do DC atual | Qualquer mudança de estrutura ou de comportamento no DC atual pode quebrar outro produto                                                                                                                            | DC atual intacto, em release própria; o v2 escreve só no schema `agenor_coleta`; verificação de que o DC atual sobe, reinicia e funciona com o schema presente (A1.15) | tratado                  |
| 2   | Coluna nova obrigatória quebra o código antigo                                                                  | O DC atual e a `-apisix` inserem linhas sem conhecer as colunas do v2; uma coluna `NOT NULL` sem valor padrão faz esses inserts falharem                                                                            | O v2 não altera as tabelas do `public`; tudo o que é do v2 fica no schema `agenor_coleta` (27/10)                                                                      | tratado                  |
| 3   | Os status são `Enum` no código antigo (`collection_models.py:89,123`)                                           | Se o v2 gravar em `collected.status` ou `collection_execution.status` um valor que o código antigo não conhece (ex.: um status novo), as telas e rotas antigas que leem essa linha dão erro                         | O v2 não grava nas tabelas do `public`; os status novos (`CANCELLED`, `NO_SESSION`, `INFRA_FAILED`…) ficam no schema `agenor_coleta`                                   | tratado                  |
| 4   | Os sweepers antigos olham **todas** as execuções do banco                                                       | O `find_stuck_collected_ids` (`orchestrator_repository.py`) pega qualquer execução `PENDING` ou `PROCESSING` parada, sem saber de onde veio. Na `-apisix`, em modo ativo, ele **republica a coleta na fila antiga** | O v2 não grava nas tabelas do DC atual (§3.4), então os sweepers antigos não enxergam as coletas dele. O alerta sobre o sweeper ativo da `-apisix` continua        | tratado (detalhe no ADR) |
| 5   | A tabela `collection_attempt` já é usada pelo orquestrador antigo                                               | Se o v2 reaproveitasse essa tabela, os sweepers antigos continuariam gravando nela (o shadow registra tentativas a cada 2 h)                                                                                        | O v2 usa uma **tabela de tentativas própria**, sem reaproveitar `collection_attempt` (§3.1)                                                                        | tratado                  |
| 6   | O DC atual roda `alembic upgrade head` toda vez que sobe                                                        | Se o v2 registrar revisões na mesma `alembic_version`, o DC atual deixa de subir e derruba o AGuiar                                                                                                                 | Versão do Alembic do v2 dentro do schema `agenor_coleta` e teste de restart do DC atual na fase 1 (A1.15)                                                              | tratado                  |
| 7   | A `-apisix` já tem heads de migração divergentes (diagnóstico, risco #6)                                        | Pode deixar de subir num restart, independente do v2                                                                                                                                                                | Alerta ao cliente; o v2 não depende dela                                                                                                                           | cliente                  |
| 8   | As listagens e consultas antigas mostrariam coletas do v2                                                       | `GET /coleta-documentos`, `/extracoes` e `consult_*` leem as tabelas do DC atual                                                                                                                                    | Com o v2 isolado (§3.4), as coletas do 2.0 não aparecem na API antiga; são consultadas pela API do v2                                                              | tratado                  |

**Fora do banco**

| #   | Ponto                                                    | Por que importa                                                                                                                                                                                                               | Como tratamos                                                                                                                                                                  | Status              |
| --- | -------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------- |
| 9   | Credenciais expostas no histórico Git                    | Chave OCI e senhas do Agnaldo vazadas continuam válidas até serem trocadas                                                                                                                                                    | Alerta ao cliente para rotacionar; o `agenor-v2` nasce sem histórico                                                                                                           | cliente             |
| 10  | Superusuário do banco do company-service em ConfigMap    | Acesso total a outro banco com senha visível                                                                                                                                                                                  | Pedido 11: usuário somente leitura em Secret                                                                                                                                   | cliente             |
| 11  | `DEBUG_MODE` e vídeo do navegador em PRD                 | Dados fiscais gravados em vídeo e em logs                                                                                                                                                                                     | Alerta ao cliente; o 2.0 nasce sem isso                                                                                                                                        | cliente             |
| 12  | O cliente continua mudando o scraper durante o 2.0       | Os workers portados ficam desatualizados                                                                                                                                                                                      | Aplicar os diffs a partir do commit registrado antes de portar cada tipo                                                                                                       | tratado (processo)  |
| 13  | Branch de partida                                        | O ponto de partida pode mudar                                                                                                                                                                                                 | Decidido em 27/10: branch mais atual de cada projeto, registrada no `ORIGEM.md`; mudanças posteriores entram por diff                                                          | tratado             |
| 14  | Prazo do cliente: acessos de teste e infra dos ambientes | Os acessos de teste aos portais atrasam o M2; a infra atrasa a fase 6. O M1 não depende do cliente                                                                                                                            | Acessos alinhados durante as fases 1 e 2; infra alinhada com antecedência antes da fase 6 (§3.10)                                                                              | cliente             |
| 15  | Validação do token do Agnaldo no DC                      | Bloqueia a autenticação entre serviços                                                                                                                                                                                        | Resolvido na A1.2 (28/10): JWT RS256 do SSO validado localmente pelo JWKS, autorização por lista de usuários de serviço (ADR-006)                                                 | tratado             |
| 16  | Limite de sessões do Agnaldo por procurador              | Mais pods simultâneos do que sessões disponíveis vira `NO_SESSION` em série                                                                                                                                                   | Começar com 6 simultâneos, como hoje, e subir medindo                                                                                                                          | tratado             |
| 17  | A virada por rota depende do contrato e do gateway       | Só é troca de rota se o DC v2 expuser aos consumidores do Agenor o mesmo contrato de solicitação e consulta do DC atual. O front e outros consumidores chegam pelo Agnaldo/APISIX com os paths do DC, e essa rota não é nossa | API do consumidor no DC v2 com o mesmo contrato (A1.1 e A1.16); mudança de rota pedida ao cliente (A6.9)                                                                       | verificar + cliente |
| 18  | Segredos no código exportado                             | A exportação tira o histórico, mas não credenciais e URLs de produção que estejam no código atual                                                                                                                             | Varredura de segredos antes do primeiro commit do `agenor-v2` (A0.1)                                                                                                           | tratado             |
| 19  | Quem consome as extrações é desconhecido                 | Os `consult_*` e o `/extracoes` não são chamados pelo front nem pelo scraper. Depois da virada, eles deixam de receber dados das coletas novas, porque o 2.0 guarda a extração só em JSON no bucket                           | Antes da virada (fase 6), identificar quem chama essas rotas pelos logs e alinhar com o cliente; as tabelas no `agenor_coleta` e a API de consulta entram quando houver consumidor | verificar + cliente |
| 20  | Instabilidade dos portais da Receita                     | A comparação scraper × 2.0 pode falhar por motivo externo                                                                                                                                                                     | Comparar por amostras repetidas                                                                                                                                                | tratado (processo)  |
| 21  | Moon limitado a 4 sessões; proxies sem limite medido     | Créditos DCTFWeb e a coleta em geral podem falhar em série se o despachante subir os limites sem medir                                                                                                                        | Limites do despachante por tipo, começando pelos de hoje (§3.4)                                                                                                                | tratado             |
| 22  | Diferenças entre o ambiente local e os clusters          | Rede, cotas, permissões e segredos só aparecem na fase 6                                                                                                                                                                      | `infra.md` com tudo o que o código precisa, manifestos locais no kind desde a fase 1, DEV antes de STG e os 8 cenários repetidos no cluster (A6.3)                                            | tratado (processo)  |

Os itens marcados **verificar** são cobertos pelas atividades A1.2, A1.15, A1.16 e, antes da virada, pela fase 6. Os marcados **cliente** entram na mensagem de pedidos e alertas da fase 0 (A0.7).

### Validações

26/10: as 8 recomendações foram aceitas como estão:

1. tentativa como unidade de execução;
2. mensagem só com identificadores;
3. Launcher com Kubernetes Jobs;
4. API nova para o Agenor e a atual para o AGuiar;
5. extrações no Postgres, idempotentes, com JSON no bucket (alterada em 27/10: só JSON no bucket nesta versão);
6. um worker por tipo, com base comum e duas imagens;
7. ZIP como job;
8. virada única por configuração.

Sujeitas a ajuste pelos padrões do Agnes Collector.

---

## 4. Roadmap

**Princípios:**

1. **Alicerce primeiro.** O Document Collector, a fila, o Launcher e a base dos workers funcionam de ponta a ponta com um worker de teste. Depois, os coletores entram um a um sobre esse alicerce.
2. **Por etapas (27/10).** O foco agora é o alicerce: base, arquitetura, estrutura, segurança e padrões. Cada processo (coletor, extração, planilhas, consultas) é detalhado, validado e ajustado na sua vez, sobre o alicerce pronto. O plano não antecipa esse detalhe.
3. **Local primeiro (26/10).** Tudo é desenvolvido, validado e testado localmente: o alicerce, os coletores e a comparação com o scraper. A subida para os ambientes (DEV, STG e PRD) é a **última etapa**. Não há pedido ao cliente para começar: partimos da branch mais atual de cada projeto (27/10). Os acessos de teste aos portais e a infra dos ambientes são alinhados no decorrer do desenvolvimento (§3.10).

O roadmap define **ordem, entregas e critérios de saída**, não datas. Os prazos do alicerce estão na §6 (M0 em 29/10, M1 em 13/11, ou 18/11 com folga); os das fases 3 a 6 entram na vez de cada uma.

### Visão geral

```
Fase 0  Preparação e ambiente local ──▶ M0  repositório e ambiente local prontos, pedidos enviados
Fase 1  Document Collector v2    ┐
Fase 2  Launcher                 ┴──▶ M1  ALICERCE: ponta a ponta local, com worker de teste
Fase 3  Base dos workers + piloto   ──▶ M2  primeiro coletor real, local, contra o portal real
Fase 4  Coletores e ZIP             ──▶ M3  todos os tipos validados localmente
Fase 6  Ambientes e virada          ──▶ M4  DEV e STG validados ──▶ M5  PRD no 2.0 ──▶ M6  scraper desligado
```

As fases 1 e 2 correm em paralelo, depois que o contrato da API (§3.2) estiver escrito. Os coletores da fase 4 podem ser divididos entre pessoas.

### Ambiente local

| Peça                                              | Como fica no ambiente local                                                                                                                                                                                                                                                                                                                                                             |
| ------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Banco                                             | Postgres local com o esquema do DC atual, criado pelas migrações do próprio código, e dados de exemplo gerados por nós                                                                                                                                                                                                                                                                  |
| DC atual                                          | Rodando localmente sobre o mesmo banco, para os testes de regressão e de isolamento                                                                                                                                                                                                                                                                                                     |
| Cluster                                           | Kubernetes local (kind ou k3d) para os Jobs do Launcher                                                                                                                                                                                                                                                                                                                                 |
| Fila                                              | **Local.** O DC v2 e o Launcher falam com a fila por uma interface com dois adaptadores: o da OCI Queue, usado nos ambientes, e um local, usado no desenvolvimento e nos testes. O local simula visibilidade, reentrega e apagamento, para reproduzir os 8 cenários do M1. A fila existente não é usada, porque é consumida pelo scraper. O adaptador da OCI é validado em DEV (fase 6) |
| Bucket                                            | Armazenamento compatível com S3 rodando localmente; o bucket da OCI só nos ambientes                                                                                                                                                                                                                                                                                                    |
| Agnaldo                                           | O real, com os usuários de serviço que já temos dos outros produtos                                                                                                                                                                                                                                                                                                                     |
| Portais, proxies, Moon, session-manager, hCaptcha | Os reais, com procurador, certificado e CNPJs de teste. Os acessos são alinhados antes do piloto (fase 3) e dos coletores que precisam deles (fase 4)                                                                                                                                                                                                                                   |
| Scraper                                           | Rodando localmente com as mesmas entradas, para a comparação                                                                                                                                                                                                                                                                                                                            |

### Fase 0: preparação e ambiente local

**Objetivo:** ter onde trabalhar e pedir cedo o que depende do cliente.

**Entregas:**

- Pasta de trabalho `agenor-v2` com **repositórios separados**, no padrão do cliente (decidido em 27/10). A pasta reúne o contexto, e o repositório dela guarda só a documentação:
  ```
  agenor-v2/                     repositório de docs: README, AGENTS.md, docs/ (plano, contexto, diagnóstico, cliente/, arquitetura/)
    agenor-document-collector/   repositório próprio: DC v2, a partir do DC atual (ORIGEM.md)
    agenor-launcher/             repositório próprio (novo)
    agenor-workers/              repositório próprio: core/ e workers/ (coletores portados nas fases 3 e 4)
    agenor-common/               repositório próprio: evento da fila, modelos da API e interface de fila, instalado por tag Git
    referencia/                  snapshots do scraper e do download service, fora do Git, só para consulta
  ```
  Um monorepo, como o do Agnes Collector, traria ganhos (contrato num PR só), mas seguimos o padrão de repositórios separados do Agenor. O `agenor-common` compensa a parte do contrato.
- ~~CI de qualidade em cada projeto~~ Fora por enquanto (27/10): pipelines e Sonar são infra do cliente e não são alterados por nós. A verificação é o `verify.sh` de cada repositório, rodado localmente; o CI entra quando for combinado com o cliente.
- `docs/arquitetura/`: a §3 convertida em ADRs e um `infra.md` com só o que o código precisa do ambiente.
- **Ambiente local** montado (tabela acima).
- **Documento enviado ao cliente** (`ag-capital/agenor/entregaveis/`), com os alertas.
- **Acessos de teste** (§3.10, A2 e A3) em alinhamento, para estarem prontos antes do piloto. A infra dos ambientes (parte B) fica para a fase 6.

**Critério de saída (M0):**

- o repositório compila e os testes atuais passam;
- o ambiente local sobe o DC atual sobre o banco local.

**Depende do cliente:** nada.

### Fase 1: Document Collector v2

**Objetivo:** o DC v2 passa a ser o orquestrador do desenho novo, sem afetar o DC atual.

**Entregas:**

- Migrações no schema `agenor_coleta` (coleta, tentativa, itens, histórico de eventos e `status_text`), com a versão do Alembic dentro do schema.
- Imagem própria do DC v2, com um comando só de migração. No kind, o DC v2 sobe por manifestos em `local/`, com a migração como Job antes do deploy. Sem chart nem values (infra do cliente).
- **API do consumidor** com o mesmo contrato de solicitação e consulta do DC atual, para que a virada seja só troca de rota (§3.13, item 17).
- API v2 do worker e do Launcher (§3.2), autenticada por token do Agnaldo.
- Interface de fila com adaptador local e adaptador da OCI Queue, usada pelo DC v2 e pelo Launcher.
- Cálculo de status único no DC.
- Despachante: lock, capacidade, publicação e confirmação, com varredura de 1 min.
- Política de retentativa e detecção de abandono.
- Configuração validada (`pydantic-settings`), logs em JSON, OTel e métricas de negócio.
- DC v2 só com o que é do 2.0: sem as rotas antigas sobre o `public`, sem `consult_*`, `/extracoes` e `query_consult`, sem os endpoints de teste e debug e **sem o orquestrador, os sweepers e o consumo da fila antiga**.
- **Verificação de isolamento:** o DC atual sobe, reinicia e funciona com o schema `agenor_coleta` presente, e não enxerga as coletas do v2.

**Critério de saída, no ambiente local:**

- O DC v2 roda ao lado do DC atual, no mesmo banco, e o DC atual funciona igual, inclusive depois de reiniciar.
- Uma coleta pedida pela API do consumidor do DC v2 gera uma tentativa, é despachada e aparece na fila local no formato novo.

**Depende do cliente:** nada. Os usuários de serviço do Agnaldo já existem, e a fila é local.

### Fase 2: Launcher

**Objetivo:** o Launcher transforma a mensagem em um Job e acompanha até o fim.

**Entregas:**

- Projeto `agenor-launcher` com:
  - consumo da fila;
  - catálogo de tipos;
  - criação do Job com nome determinístico;
  - confirmação após criar;
  - observação dos Jobs e aviso ao DC;
  - reconciliação ao reiniciar;
  - teto de segurança;
  - health check real e métricas.
- Manifestos locais do Launcher em `local/` (Deployment, ServiceAccount e Role só no namespace dos workers), para o M1 no kind. Sem chart nem values: o que o Launcher precisa nos ambientes (RBAC, namespace, recursos) está no `infra.md`, e o deploy é do cliente (fase 6).
- **Worker de teste** (`noop`): lê a entrada, dá sinal de vida, "coleta" um arquivo fictício, grava no bucket e encerra. Pode ser configurado para falhar, travar ou estourar memória.

**Critério de saída (M1, alicerce pronto):** no ambiente local, com o cluster local e o worker de teste, todos os cenários abaixo se comportam como o desenho manda:

| Cenário                      | Resultado esperado                 |
| ---------------------------- | ---------------------------------- |
| Sucesso                      | Coleta `FINISHED`                  |
| Erro recuperável             | Nova tentativa com espera          |
| Erro não recuperável         | `FAILED` imediato                  |
| Pod morto no meio            | Abandono detectado, nova tentativa |
| Prazo estourado              | `TIMED_OUT`, nova tentativa        |
| Mensagem entregue duas vezes | Uma execução só                    |
| Launcher reiniciado no meio  | Nada perdido, nada duplicado       |
| Capacidade cheia             | O resto espera no banco            |

**Depende do cliente:** nada; fila e armazenamento são locais.

### Fase 3: base dos workers e coletor piloto

**Objetivo:** a base comum pronta e provada com um coletor real.

**Entregas:**

- `agenor-workers/core`:
  - entrada e descarte de tentativa obsoleta;
  - sinal de vida e cancelamento;
  - ciclo de sessão do Agnaldo (reservar, manter, trocar perfil, sempre devolver);
  - chave determinística no bucket;
  - retomada;
  - registro de itens e JSON da extração no bucket;
  - erros tipados;
  - SIGTERM.
- Imagens `agenor-worker` e `agenor-worker-chrome`, construídas localmente.
- **Piloto: Fontes Pagadoras.** É pequeno (cerca de 370 linhas), só HTTP, tem extração e hoje não tem retomada, então exercita a base inteira.

**Critério de saída (M2):** o piloto roda no ambiente local contra o portal real, e o resultado bate com o do scraper para os mesmos clientes (itens, arquivos e dados extraídos).

**Depende do cliente:** procurador, certificado e CNPJs de teste, e acesso aos proxies (§3.10, A2 e A3), alinhados durante as fases 1 e 2.

### Fase 4: coletores e ZIP

**Objetivo:** todos os tipos atuais no modelo de workers.

**Ordem**, do menor risco para o maior, para que a base amadureça antes dos coletores pesados:

| #   | Worker                          | Por que nessa posição                                              |
| --- | ------------------------------- | ------------------------------------------------------------------ |
| 1   | DIRF                            | Pequeno, só HTTP                                                   |
| 2   | GPS (CNPJ, CEI, filiais)        | Médio; fluxo próprio da Dataprev                                   |
| 3   | PER/DCOMP e PER/DCOMP Consultor | Inclui o leitor de PDFs que hoje usa o SQL livre                   |
| 4   | DCTF                            | Exige a imagem com Chrome                                          |
| 5   | Créditos DCTFWeb                | Exige o Moon (Selenium remoto)                                     |
| 6   | DARF                            | Session-manager, hCaptcha e SERPRO; cerca de 3,6 mil linhas        |
| 7   | DCTFWeb                         | O maior (cerca de 3 mil linhas mais o parser); mais regras fiscais |
| —   | ZIP                             | Pode entrar a qualquer momento depois do piloto                    |

**Para cada worker:**

- porta o fluxo e os parsers atuais;
- usa a chave padrão no bucket;
- tem testes dos parsers;
- passa pela comparação local com o scraper.

**Critério de saída (M3):** todos os tipos e o ZIP validados no ambiente local pela comparação.

**Depende do cliente:** acesso de teste ao Moon, ao session-manager e ao hCaptcha (§3.10, A4), alinhado durante a fase 3.

### Fase 5: extrações e consulta (fora desta versão)

Decidido em 27/10: as tabelas de extração no `agenor_coleta`, a API de consulta e a cópia do histórico ficam para depois (§3.5). Nesta versão, a extração fica em JSON no bucket, gravada pelos workers desde a fase 3. A numeração das fases foi mantida.

### Fase 6: ambientes e virada (última etapa)

**Objetivo:** levar aos ambientes o que já foi validado localmente e virar a produção.

**Entregas:**

- Infra dos ambientes pronta (§3.10, parte B).
- Pipeline de build e deploy: imagens no Harbor e `helm upgrade --install`.
- **DEV:** DC v2 em release própria ao lado do atual, Launcher e workers. Os 8 cenários do M1 são repetidos no cluster.
- **STG:**
  - comparação de todos os tipos com a versão atual;
  - verificação de que a `-apisix` não enxerga as coletas do v2 (M4).
- Revisão de segurança do caminho novo (§3.7).
- Painéis e alertas sobre as métricas do DC e do Launcher.
- **Roteiro da virada e da volta**, ensaiado em STG.

**Passos em PRD (§3.9):**

1. Deploy do Agenor 2.0 em PRD (DC v2, Launcher e workers), ao lado da versão atual.
2. Apontar os consumidores do Agenor para o DC v2 (M5). O que já estava na versão atual termina lá.
3. Janela de observação com a versão atual no ar, pronta para voltar.
4. Desligar o scraper (M6). O Agenor deixa de usar o DC atual; o destino dele é decisão do cliente.

**Depende do cliente:** toda a parte B da §3.10, em DEV, STG e PRD, a mudança de rota ou URL dos consumidores e uma janela combinada para a virada.

### Marcos

| Marco  | Significa                                                                                                                 | Fase  |
| ------ | ------------------------------------------------------------------------------------------------------------------------- | ----- |
| **M0** | Repositório e ambiente local prontos, CI rodando, pedidos enviados                                                        | 0     |
| **M1** | **Alicerce pronto:** DC, fila, Launcher e Job funcionando ponta a ponta no ambiente local, com todos os cenários de falha | 1 e 2 |
| **M2** | Primeiro coletor real (Fontes Pagadoras) ponta a ponta, local, contra o portal real                                       | 3     |
| **M3** | Todos os tipos validados localmente                                                                                       | 4     |
| **M4** | DEV e STG validados, com a comparação em STG                                                                              | 6     |
| **M5** | Produção rodando no 2.0                                                                                                   | 6     |
| **M6** | Scraper desligado                                                                                                         | 6     |

### Riscos do roadmap

Só os que afetam prazo.

| Risco                                                              | Efeito                                        | Como tratamos                                                                                                            |
| ------------------------------------------------------------------ | --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Acessos de teste aos portais                                       | Atrasam M2 e parte da fase 4                  | O M1 não depende deles (fila, bucket e Agnaldo já resolvidos). Pedidos alinhados durante as fases 1 e 2 (§3.10, A2 a A4) |
| Prazo da infra dos ambientes                                       | Atrasa M4                                     | Alinhada no decorrer do desenvolvimento, com antecedência suficiente antes da fase 6 (§3.10, parte B)                    |
| Diferenças entre o ambiente local e os clusters                    | Surpresas na fase 6 (rede, cotas, permissões) | `infra.md` com tudo o que o código precisa, manifestos locais no kind desde a fase 1 e DEV antes de STG                                 |
| O cliente continua alterando o scraper durante o 2.0               | Os workers portados ficam desatualizados      | Aplicar os diffs a partir do commit registrado antes de portar cada tipo                                                 |
| Instabilidade dos portais da Receita                               | A comparação falha por motivo externo         | Comparar por amostras repetidas, não por uma execução só                                                                 |
| Validação do token do Agnaldo no DC                                | Bloqueia a autenticação                       | Resolver no início da fase 1                                                                                             |
| Sweeper ativo da `-apisix` republicar coletas do v2 na fila antiga | A mesma coleta roda no scraper e no 2.0       | v2 isolado das tabelas do DC atual (§3.4); verificação em STG na fase 6                                                  |

Lista completa dos pontos de atenção, inclusive os que não afetam prazo: §3.13.

### Fora deste roadmap (depois)

- Front.
- eSocial e a integração do Agnes Collector como mais um motor.
- Agendamentos recorrentes (Temporal).
- Remoção, no DC atual, das rotas do Agenor, dos `consult_*` e do `query_consult`, depois de saber quem chama cada rota.
- Alta disponibilidade do Launcher.
- Separação do banco entre Agenor e AGuiar.
- Extrações estruturadas: tabelas no `agenor_coleta`, API de consulta e cópia do histórico do `public` (§3.5).
- Fim do acesso direto ao banco do company-service.

### Validações

26/10:

1. **Alicerce primeiro.** É o objetivo principal desta fase; os coletores vêm depois, como consequência e teste do alicerce.
2. **Piloto (Fontes Pagadoras) só depois do alicerce pronto (M1).**
3. **Ordem dos coletores** como proposta, também depois do M1.
4. **Sem datas** por enquanto.

26/10 (refinamento): fases 1 e 6 ajustadas ao modelo de duas releases no mesmo banco; Secret do bucket antecipado para o M1.

26/10 (refinamento): **local primeiro.** Tudo é validado e testado no ambiente local (M1 a M3), e os ambientes DEV, STG e PRD viram a última etapa (fase 6, M4 a M6). Os pedidos ao cliente se dividem em acessos de teste (agora) e infra dos ambientes (pedida cedo, usada no fim).

Plano a ser refinado depois da primeira versão completa.

---

## 6. Atividades

Primeira versão, para ser refinada. As atividades seguem as fases do roadmap.

**Tamanho relativo:** **P** pequena, **M** média, **G** grande.

**Prazos do alicerce (decididos em 27/10, recalibrados no mesmo dia).** Valem para as fases 0 a 2; as fases 3 a 6 ganham prazo na vez de cada uma.

- **Premissas:** uma pessoa (Lucas), em dedicação integral (8 h por dia), desenvolvendo com o Claude Code; as horas já consideram esse ganho. Início em 27/10; feriado de 02/11 descontado.
- **Esforço:** fase 0, 12 h; fase 1, 58 h; fase 2, 28 h. Total de cerca de 98 h, ou cerca de 117 h com folga de 20%. Com uma pessoa só, as fases correm em sequência.
- **Acompanhamento:** as tarefas do projeto "AG Capital - Agenor" no Squads (#337 a #346) agrupam estas atividades, com as mesmas horas e datas. O Squads mostra as datas sem folga.

  | Tarefa no Squads                               | Atividades                | Horas | Datas         |
  | ---------------------------------------------- | ------------------------- | ----- | ------------- |
  | #337 Repositório                               | A0.1 a A0.3               | 1     | 27/10         |
  | #338 Documentação da arquitetura               | A0.6                      | 2     | 28/10         |
  | #339 Ambiente local e verificações automáticas | A0.4, A0.5                | 8     | 28 a 29/10    |
  | #340 DC 2.0: base                              | A1.1 a A1.4, A1.13, A1.17 | 20    | 29/10 a 03/11 |
  | #341 DC 2.0: orquestração                      | A1.5 a A1.11              | 28    | 03 a 09/11    |
  | #342 DC 2.0: API e monitoramento               | A1.12, A1.14 a A1.16      | 10    | 09 a 10/11    |
  | #343 Launcher                                  | A2.1 a A2.9               | 20    | 10 a 12/11    |
  | #344 Validação de ponta a ponta                | A2.10                     | 8     | 13/11         |
  | #345 Acessos de teste (cliente)                | A0.8                      | —     | 03 a 18/11    |

  A A1.3b (modelagem de dados, 29/10) não está em nenhuma tarefa do Squads; o Lucas decide como registrá-la. A #341 ficou pausada até ela fechar.

- **Datas:**

  | Marco             | Sem folga | Com folga de 20% |
  | ----------------- | --------- | ---------------- |
  | M0                | 29/10     | 29/10            |
  | Fim da fase 1     | 10/11     | —                |
  | **M1 (alicerce)** | **13/11** | **18/11**        |

- Se a dedicação mudar, as datas são recalculadas a partir das horas.

**Caminho crítico:**

```
[A0.1 ∥ A0.6 (ADRs)] → A1.1 (contrato) → [Fase 1 ∥ Fase 2] → A2.10 (M1, com o ambiente local da A0.5) → Fase 3 → A3.10 (M2) → Fase 4 → A4.9 (M3) → A6.3 (DEV) → A6.4 (M4) → A6.9 (M5)
```

A coluna "Depende de" usa os códigos das atividades. **Cliente** indica um item de infra que depende do cliente (§3.10).

### Fase 0: preparação (12 h, M0 em 29/10)

Revisada item a item em 27/10.

| #    | Atividade                                                                                                                                                                                                                                                            | Depende de | Tam. | Horas |
| ---- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ---- | ----- |
| A0.1 | ✅ 27/10. Criar o `agenor-v2` e exportar Document Collector, scraper e download service da branch mais atual de cada projeto (commit mais recente depois do `git fetch`), com branch e commit no `ORIGEM.md` e varredura de segredos antes do primeiro commit (§3.13, item 18) | —          | P    | 0,5   |
| A0.2 | ✅ 27/10. Esqueleto do `agenor-launcher`: Python 3.12, `pydantic-settings`, health e métricas                                                                                                                                                                                  | A0.1       | P    | 0,25  |
| A0.3 | ✅ 27/10. Esqueleto do `agenor-workers`: `core/` e `workers/`                                                                                                                                                                                                                  | A0.1       | P    | 0,25  |
| A0.4 | Fazer os testes herdados do DC passarem (condição do M0) ✅ 27/10. O CI de qualidade (Sonar, SBOM) ficou fora: pipelines são infra do cliente, e o CI entra quando for combinado com ele                 | A0.1       | M    | 5     |
| A0.5 | ✅ 27/10 (`local/`). **Ambiente local** (§4): Postgres com o esquema do DC atual, DC atual rodando local, cluster local (kind ou k3d), armazenamento local e acesso dos pods ao DC e ao armazenamento                                                                                     | A0.1       | M    | 3     |
| A0.6 | ✅ 27/10 (`docs/arquitetura/`). Converter a §3 em ADRs (isolamento no schema `agenor_coleta`, contratos, status, despachante, autenticação) e escrever o `infra.md`                                                                                                                                      | —          | M    | 2     |
| A0.7 | Enviar ao cliente o documento de `ag-capital/agenor/entregaveis/` e os alertas (§3.10). Não bloqueia nada                                                                                                                                                            | —          | P    | 0,5   |
| A0.8 | Alinhar os acessos de teste (§3.10, A2 e A3: procurador, certificado, CNPJs de teste e proxies), durante as fases 1 e 2, para estarem prontos na A3.10                                                                                                               | A0.7       | P    | 0,5   |

### Fase 1: Document Collector v2 (58 h, até 10/11)

Revisada item a item em 27/10.

| #     | Atividade                                                                                                                                                                                                                                                                                                           | Depende de        | Tam. | Horas |
| ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------- | ---- | ----- |
| A1.1  | ✅ 28/10. **Contrato:** OpenAPI da API do consumidor, do worker e do Launcher, e esquema do evento da fila                                                                                                                                                                                                                    | A0.1, A0.6        | M    | 3     |
| A1.2  | ✅ 28/10 (JWT local pelo JWKS do SSO, ADR-006). Validação do token do Agnaldo no DC (usuários de serviço que já temos). É risco: começa no início da fase                                                                                                                                                                                                           | A0.1              | M    | 3     |
| A1.3  | ✅ 28/10. Migrações no schema `agenor_coleta`: coleta, tentativa, itens, histórico de eventos e `status_text`                                                                                                                                                                                                                     | A1.1              | M    | 3     |
| A1.3b | ✅ 29/10 (`arquitetura/modelo-de-dados.md`, revisão `a057fe7dbe85`). **Modelagem de dados do `agenor_coleta`** (aberta em 29/10): para cada tabela e coluna, para que serve, quem escreve, quem lê e o que substitui no `public`, só com o que a arquitetura precisa agora; de/para das tabelas do `public`; depois do ok, modelo, migração `0001` reescrita, ADRs e harness ajustados. Numerada como "b" da A1.3 porque refaz o resultado dela sem renumerar as seguintes; entrou depois do dimensionamento das 58 h | A1.3              | M    | —     |
| A1.4  | ✅ 28/10. Imagem própria do DC v2 com um comando só de migração (versão do Alembic dentro do `agenor_coleta`); tirar o Alembic do entrypoint do v2; manifestos em `local/` para o DC v2 no kind, com a migração como Job antes do deploy. Sem chart nem values                                                                                                                                                         | A1.3              | M    | 3     |
| A1.5  | ✅ 29/10. Endpoints de entrada, início, sinal de vida e fim da tentativa                                                                                                                                                                                                                                                      | A1.3b             | M    | 5     |
| A1.6  | Endpoints idempotentes de itens; itens já coletados                                                                                                                                                                                                                                                                 | A1.3b             | M    | 3     |
| A1.7  | Cálculo único do status da coleta                                                                                                                                                                                                                                                                                   | A1.5, A1.6        | M    | 3     |
| A1.8  | **Despachante:** lock, capacidade, publicar, confirmar e varredura de 1 min                                                                                                                                                                                                                                         | A1.3b, A1.17      | G    | 8     |
| A1.9  | Política de retentativa; falha técnica separada da de negócio                                                                                                                                                                                                                                                       | A1.7              | M    | 3     |
| A1.10 | Detecção de abandono e recebimento dos avisos do Launcher                                                                                                                                                                                                                                                           | A1.5, A1.9        | M    | 5     |
| A1.11 | ✅ 29/10 (catálogo fechado em `EventName`). Histórico de eventos                                                                                                                                                                                                                                                                                                | A1.3b             | P    | 1     |
| A1.12 | DC v2 rodando no ambiente local ao lado do DC atual, no mesmo banco: no `local/compose.yaml` no dia a dia e no kind pelos manifestos da A1.4                                                                                                                                                                                                                                                 | A0.5, A1.4, A1.13 | P    | 1,5   |
| A1.13 | ✅ 28/10, com o `ruff` num commit só de formatação. **Limpar o DC v2** do que não é do 2.0: rotas antigas sobre o `public` (inclusive as do AGuiar), `consult_*`, `/extracoes`, `query_consult`, `/test-collected`, `/sentry-debug`, CORS aberto, orquestrador antigo, sweepers e consumo da fila antiga. No fim, adotar o `ruff` no DC v2, num commit só de formatação | A0.1              | M    | 3     |
| A1.14 | Configuração validada, logs em JSON, OTel e métricas de negócio                                                                                                                                                                                                                                                     | A0.1              | M    | 3     |
| A1.15 | Verificar no ambiente local que o DC atual sobe, reinicia e funciona com o schema `agenor_coleta` presente, e não enxerga as coletas do v2 (§3.13, itens 1, 4, 6 e 8). A `-apisix` é verificada em STG (A6.4)                                                                                                           | A1.12             | P    | 1,5   |
| A1.16 | **API do consumidor:** solicitar a coleta, consultar status, listar e baixar, com o mesmo contrato do DC atual para o Agenor, sobre o `agenor_coleta` (§3.13, item 17)                                                                                                                                                  | A1.3b, A1.7       | M    | 4     |
| A1.17 | ✅ 28/10 (adaptador local em Postgres). **Interface de fila**, usada pelo DC v2 e pelo Launcher: publicar, receber, renovar e apagar, com adaptador local (visibilidade, reentrega e apagamento) e adaptador da OCI Queue. O da OCI é validado em DEV (A6.3)                                                                                                | A0.1              | M    | 5     |

### Fase 2: Launcher (28 h, M1 em 13/11, 18/11 com folga)

Revisada item a item em 27/10.

| #     | Atividade                                                                                                                                                    | Depende de              | Tam. | Horas |
| ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------- | ---- | ----- |
| A2.1  | Consumo da fila pela interface (A1.17): espera longa, renovação e tratamento de erro                                                                         | A0.2, A1.17             | M    | 3     |
| A2.2  | Catálogo de tipos: imagem, comando, recursos, prazo                                                                                                          | A0.2                    | P    | 1,5   |
| A2.3  | Criação do Job (nome determinístico, "já existe" = ok) e confirmação da mensagem                                                                             | A2.1, A2.2              | M    | 3     |
| A2.4  | Observação dos Jobs e aviso ao DC                                                                                                                            | A2.3, A1.10             | M    | 4     |
| A2.5  | Reconciliação ao iniciar                                                                                                                                     | A2.4                    | P    | 1,5   |
| A2.6  | Teto de segurança do cluster                                                                                                                                 | A2.3                    | P    | 1,5   |
| A2.7  | Health check real, métricas e OTel                                                                                                                           | A2.1                    | P    | 1,5   |
| A2.8  | Manifestos do Launcher em `local/` (Deployment, ServiceAccount e Role no namespace dos workers), para instalá-lo no kind na A2.10. Sem chart nem values; o que ele precisa nos ambientes vai no `infra.md` | A0.2                    | M    | 3     |
| A2.9  | Worker de teste (`noop`) com modos de falha                                                                                                                  | A0.3, A1.1              | P    | 1     |
| A2.10 | **Testes dos 8 cenários no ambiente local → M1**                                                                                                             | Fase 1, A2.1–A2.9, A0.5 | M    | 8     |

### Fase 3: base dos workers e piloto (depois do M1)

| #     | Atividade                                                                                                                              | Depende de                                 | Tam. |
| ----- | -------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------ | ---- |
| A3.1  | core: entrada, descarte de obsoleta, sinal de vida, cancelamento, SIGTERM                                                              | A2.10                                      | M    |
| A3.2  | core: cliente do Agnaldo (token; reservar, manter, trocar perfil e devolver a sessão)                                                  | A3.1                                       | M    |
| A3.3  | core: chave determinística no bucket e retomada                                                                                        | A3.1                                       | M    |
| A3.4  | core: registro de itens no DC e JSON da extração no bucket                                                                             | A3.1                                       | M    |
| A3.5  | core: catálogo de erros tipados e encerramento                                                                                         | A3.1                                       | P    |
| A3.6  | core: proxies (reaproveitar o transporte atual)                                                                                        | A3.1                                       | P    |
| A3.7  | Imagens `agenor-worker` e `agenor-worker-chrome`, construídas localmente                                                               | A0.3                                       | P    |
| A3.8  | Worker Fontes Pagadoras                                                                                                                | A3.1–A3.7                                  | M    |
| A3.9  | Ferramenta de comparação scraper × 2.0: itens, arquivos e extrações (JSON do 2.0 contra as tabelas do scraper), usada também na fase 4 | A3.4                                       | M    |
| A3.10 | **Validação local do piloto contra o portal real → M2**                                                                                | A3.8, A3.9, A0.8 (cliente: §3.10, A2 e A3) | P    |

### Fase 4: coletores e ZIP (depois do M2)

Cada worker inclui: portar o fluxo e os parsers, usar a chave padrão, testes dos parsers e comparação local com o scraper.

| #    | Atividade                                                                   | Depende de                 | Tam. |
| ---- | --------------------------------------------------------------------------- | -------------------------- | ---- |
| A4.1 | Worker DIRF                                                                 | A3.10                      | P    |
| A4.2 | Worker GPS (CNPJ, CEI, filiais)                                             | A3.10                      | M    |
| A4.3 | Workers PER/DCOMP e PER/DCOMP Consultor, com o leitor de PDFs sem SQL livre | A3.10                      | G    |
| A4.4 | Worker DCTF (imagem com Chrome)                                             | A3.10                      | M    |
| A4.5 | Worker Créditos DCTFWeb (Moon)                                              | A3.10, cliente (§3.10, A4) | M    |
| A4.6 | Worker DARF (session-manager, hCaptcha, SERPRO)                             | A3.10, cliente (§3.10, A4) | G    |
| A4.7 | Worker DCTFWeb                                                              | A3.10                      | G    |
| A4.8 | Worker ZIP (streaming do download service) e criação da tentativa ZIP no DC | A3.10                      | M    |
| A4.9 | **Validação local de todos os tipos → M3**                                  | A4.1–A4.8                  | M    |

### Fase 5: extrações e consulta (fora desta versão)

A5.1 a A5.3 saem do escopo desta versão (§3.5).

### Fase 6: ambientes e virada (última etapa, depois do M3)

| #     | Atividade                                                                                                           | Depende de                        | Tam. |
| ----- | ------------------------------------------------------------------------------------------------------------------- | --------------------------------- | ---- |
| A6.1  | Infra dos ambientes pronta (§3.10, parte B)                                                                         | cliente                           | —    |
| A6.2  | Pipeline de build e deploy dos três projetos (imagens no Harbor, chart, values): **feito pelo cliente**, a partir do `infra.md`; nós acompanhamos                      | A0.4, A6.1                        | M    |
| A6.3  | **DEV:** DC v2 em release própria ao lado do atual, Launcher e workers; repetir os 8 cenários do M1 no cluster      | A6.2, A2.8, A4.9                  | M    |
| A6.4  | **STG:** comparação de todos os tipos com a versão atual e verificação de que a `-apisix` não enxerga o v2 → **M4** | A6.3                              | M    |
| A6.5  | Revisão de segurança do caminho novo (§3.7)                                                                         | A4.9                              | M    |
| A6.6  | Painéis e alertas                                                                                                   | A1.14, A2.7                       | P    |
| A6.7  | Roteiro da virada e da volta, ensaiado em STG                                                                       | A6.4                              | M    |
| A6.8  | Deploy em PRD ao lado da versão atual                                                                               | A6.4–A6.7, cliente (infra em PRD) | P    |
| A6.9  | **Virada em PRD: consumidores apontam para o DC v2 → M5**                                                           | A6.8, cliente (rota ou URL)       | P    |
| A6.10 | Janela de observação e **desligamento do scraper → M6**                                                             | A6.9                              | P    |
