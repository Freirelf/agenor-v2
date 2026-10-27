# ADR-008: Observabilidade no padrão do Agnes Collector, com logs em JSON

- **Status:** Aceito
- **Data:** 2026-10-27
- **Origem:** plano, §3.8 e §3.12

## Contexto

- O Agnes Collector usa OpenTelemetry para o Alloy do cliente, `/metrics` com ServiceMonitor e logs em texto livre.
- No 2.0, os workers rodam como Jobs de vida curta: um ServiceMonitor não alcança um pod que já terminou.
- O health check atual do scraper não verifica se ele está de fato consumindo a fila.
- Uma coleta atravessa DC, fila, Launcher e Job. Sem um identificador comum, é impossível seguir uma execução nos logs.

## Decisão

- **Traces:** OpenTelemetry via OTLP para o Alloy do cliente, ligado por `OTEL_EXPORTER_OTLP_ENDPOINT`. `OTEL_SERVICE_NAME` por serviço; `collected_id` e `attempt_id` como atributos.
- **Métricas:** `/metrics` (Prometheus) no DC e no Launcher, com ServiceMonitor. Os workers não expõem métricas; as **métricas de negócio saem do DC**, que tem o estado:
  - coletas por status e por tipo;
  - tentativas despachadas e em execução;
  - duração e resultado por tipo;
  - motivos de falha.
- **Logs:** em JSON, com `collected_id`, `attempt_id` e o nome do Job em toda linha. Melhoria sobre o Agnes Collector.
- **Health checks:** refletem se o serviço está de fato funcionando. O do DC verifica o banco; o do Launcher verifica se ele está consumindo a fila e falando com a API do Kubernetes.
- **Sem dado fiscal ou pessoal** em logs, traces ou rótulos de métricas. Sem `DEBUG_MODE` e sem gravação de vídeo do navegador em produção.

## Alternativas consideradas

- **Pushgateway para as métricas dos Jobs.** Mais um componente para o cliente operar, e o DC já sabe tudo o que o Job informaria.
- **Logs em texto livre, como no Agnes Collector.** Dificultam filtrar por coleta ou tentativa.

## Consequências

- O cliente precisa do ServiceMonitor do DC e do Launcher, do endpoint OTLP e da coleta dos logs dos Jobs antes da limpeza pelo `ttlSecondsAfterFinished` (pedido 13).
- O `core` dos workers configura o log em JSON e o OTel, e cada serviço faz o mesmo no seu repositório.
