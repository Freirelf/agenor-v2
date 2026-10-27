# ADR-009: Virada única pelos consumidores, sem chave de ambiente

- **Status:** Aceito
- **Data:** 2026-10-27
- **Origem:** plano, §1 ("Princípios"), §3.9, §3.12 ("Não adotados agora") e §3.13, item 17

## Contexto

- O DC atual precisa continuar no ar para o AGuiar, independente do 2.0.
- O 2.0 roda em releases próprias e num schema próprio ([ADR-001](adr-001-isolamento-no-schema-agenor-v2.md)).
- O Agnes Collector virou o mecanismo novo atrás de chaves de ambiente (`QUEUE_PROVIDER_*`), no mesmo código.
- A convivência tipo a tipo (alguns tipos no scraper, outros no 2.0) foi descartada na Visão.
- Os consumidores do Agenor chegam ao DC pelo Agnaldo/APISIX, com os paths do DC, e essa rota não é nossa.

## Decisão

1. **Desenvolvimento e validação no ambiente local**, inclusive a comparação com o scraper (fases 1 a 5).
2. **DEV e STG** com o 2.0 em releases próprias. Em STG, as mesmas solicitações rodam na versão atual e no 2.0, e comparamos, por tipo, os itens, os arquivos e os dados extraídos (JSON do 2.0 contra as tabelas da versão atual).
3. **Deploy em PRD** do DC v2, do Launcher e dos workers, ao lado da versão atual e no mesmo banco. O DC atual e o scraper não são tocados.
4. **Virada única, pelos consumidores:** eles passam a chamar o DC v2, por rota ou URL. As coletas novas vão todas para o 2.0; o que já estava na versão atual termina lá.
5. **Volta:** durante uma janela combinada (ex.: duas semanas), a versão atual continua no ar. Voltar é apontar os consumidores de novo para o DC atual.
6. **Fim da janela:** o scraper é desligado. O que fazer com o DC atual, inclusive para o AGuiar, é decisão do cliente.

**Não há chave de ambiente:** a versão atual não recebe código novo.

## Alternativas consideradas

- **Chave de ambiente no DC atual,** como no Agnes Collector. Exigiria mudar o DC que atende o AGuiar e manter os dois caminhos no mesmo código.
- **Virada tipo a tipo.** Dois sistemas ativos para o mesmo produto por semanas, com o status de uma coleta dependendo do tipo.

## Consequências

- A virada só é troca de rota se a API do consumidor do DC v2 tiver o mesmo contrato do DC atual (A1.1 e A1.16).
- A mudança de rota no Agnaldo/APISIX é pedida ao cliente (A6.9).
- Na janela de volta, coletas pedidas ao 2.0 não aparecem no DC atual. Voltar não traz essas coletas junto.
- O sweeper ativo da `-apisix` precisa estar desligado antes do 2.0 entrar em PRD (pedido 14).
