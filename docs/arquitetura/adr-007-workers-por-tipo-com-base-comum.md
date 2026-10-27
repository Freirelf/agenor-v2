# ADR-007: Um worker por tipo, com base comum, duas imagens e extração em JSON no bucket

- **Status:** Aceito
- **Data:** 2026-10-27
- **Origem:** plano, §2 ("Worker" e "Base comum"), §3.0, §3.4 ("ZIP fora da requisição"), §3.5 e §3.6

## Contexto

No scraper:

- sessão, troca de perfil, status e upload são **reescritos em cada coletor**;
- os erros são classificados por trecho de mensagem, embora o catálogo `collection_error_map` já tenha a marcação de recuperável;
- só DARF, DCTF, DCTFWeb e PER/DCOMP usam chave determinística no bucket e conseguem retomar;
- só Créditos DCTFWeb usa Selenium (Moon remoto), e só o DCTF usa Chrome local (HTML→PDF); os demais são HTTP;
- as extrações são só inseridas no banco, e uma nova tentativa duplica as linhas;
- o ZIP é gerado dentro da requisição de callback do DC.

## Decisão

### Repositório e entrypoint

Um repositório, `agenor-workers`:

```text
core/      base comum
workers/   um pacote por tipo: dctf_web, creditos_dctf_web, perdcomp, perdcomp_consultant,
           dctf, dirf, darf, gps, fontes_pagadoras, zip
```

Um worker por tipo de coleta, com entrypoint `python -m workers.<tipo>`.

### O `core` executa o fluxo; o worker só implementa o que é dele

| Etapa | Quem faz |
|---|---|
| Ler a entrada; descartar se a tentativa for obsoleta | core |
| Sinal de vida a cada 1 min; parar se a tentativa for cancelada | core |
| Reservar sessão no Agnaldo, manter ativa, trocar perfil e **sempre** devolver, inclusive no SIGTERM | core |
| Planejar itens (competências, documentos) | worker |
| Pular itens já coletados | core |
| Coletar o item no portal | worker |
| Gravar no bucket com chave determinística | core |
| Extrair dados do arquivo | worker (parsers atuais) |
| Registrar o item no DC e gravar o JSON da extração no bucket | core |
| Encerrar com resultado e erro tipado | core |

### Imagens

- **padrão:** HTTP e bibliotecas de PDF;
- **com Chrome:** só para o DCTF (HTML→PDF).

O catálogo do Launcher diz qual usar. Imagem por worker só se o tamanho justificar.

### Bucket

Chave única para todos os tipos:

```text
{cnpj_certificado}/{cnpj_cliente}/{tipo}/{período}/{arquivo}
```

É o padrão que DARF, DCTF, DCTFWeb e PER/DCOMP já usam. GPS, DIRF, Fontes, Créditos e Consultor passam a usá-lo e ganham retomada. Uma nova tentativa sobrescreve o mesmo objeto.

### Dados extraídos (nesta versão)

- Os parsers e as planilhas XLSX que o scraper gera hoje são reaproveitados: as planilhas são a entrega ao usuário.
- A extração é guardada em **JSON no bucket**, com chave determinística ao lado do arquivo de origem. Uma nova tentativa sobrescreve, não duplica.
- Tabelas de extração, API de consulta e cópia do histórico ficam para depois (fase 5, fora desta versão). O formato do JSON é definido por tipo, quando cada coletor for portado.

### ZIP como worker

Quando a coleta chega a um status final, o DC cria uma tentativa do tipo `ZIP`. O Launcher a executa como qualquer worker, reaproveitando o ZIP em streaming do `agenor_download_service`. O worker ZIP não usa o Agnaldo.

### Configuração e erros

- Variáveis de ambiente validadas com `pydantic-settings`, todas documentadas num `.env.example`. Sem URL de produção fixa no código.
- Erros tipados a partir do `collection_error_map`, com a marcação de recuperável valendo de fato. Acaba a classificação por trecho de mensagem.

### O que sai

- o coletor DCTFWeb legado (Selenium);
- o stub `fill_dctf_web`;
- o data-collector;
- o Redis.

### Dependências externas por worker

| Dependência | Usada por |
|---|---|
| Agnaldo (sessão e-CAC) | todos, exceto ZIP |
| Proxies Soax e Oxylabs | portais da Receita |
| Moon | Créditos DCTFWeb |
| session-manager e hCaptcha | DARF |
| SERPRO, via Agnaldo | DARF |

## Alternativas consideradas

- **Um repositório por worker.** Multiplica pipelines e versões da base comum sem ganho: os workers mudam juntos quando o `core` muda.
- **Uma imagem por worker.** Mais builds e mais espaço no Harbor; só vale se o tamanho justificar.
- **Extração em tabelas do `agenor_v2` já nesta versão.** Não há consumidor conhecido das extrações (§3.13, item 19). Fica para quando houver.
- **ZIP dentro da requisição, como hoje.** Prende a requisição e o pod do DC por minutos.

## Consequências

- Portar um coletor é escrever só o planejamento, a coleta do item e o parser; o resto já está no `core`. O piloto (Fontes Pagadoras, A3.10) valida isso.
- Depois da virada, `/extracoes` e `consult_*` deixam de receber dados das coletas novas. Quem consome essas rotas precisa ser identificado antes da fase 6.
- O cliente continua mudando o scraper: cada tipo é portado aplicando os diffs a partir do commit registrado no `ORIGEM.md`.
