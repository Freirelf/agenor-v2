# Arquitetura

Decisões técnicas do Agenor 2.0 (ADRs) e o que o código precisa do ambiente (`infra.md`). Escritos na A0.6 a partir da §3 do [plano](../PLANO_AGENOR_2_0.md), que passa a resumir e apontar para cá.

```text
Agenor → Document Collector v2 → fila → Launcher → Job do worker (um por tentativa, um tipo por worker)
```

## Decisões (ADRs)

| ADR | Decisão |
|---|---|
| [ADR-001](adr-001-isolamento-no-schema-agenor-v2.md) | O DC v2 roda em release própria, no mesmo banco, isolado no schema `agenor_v2` |
| [ADR-002](adr-002-tentativa-e-status.md) | A tentativa é a unidade de execução, e o DC é o único dono do status |
| [ADR-003](adr-003-contratos.md) | Evento da fila só com identificadores; o worker busca a entrada no DC; APIs do worker, do Launcher e do consumidor |
| [ADR-004](adr-004-despachante-e-retentativa.md) | A tabela de tentativas é a fila de verdade; o DC decide capacidade, retentativa e abandono |
| [ADR-005](adr-005-launcher-com-kubernetes-jobs.md) | O Launcher cria um Kubernetes Job por tentativa |
| [ADR-006](adr-006-autenticacao-por-usuario-de-servico-do-agnaldo.md) | Autenticação entre serviços por usuários de serviço do Agnaldo |
| [ADR-007](adr-007-workers-por-tipo-com-base-comum.md) | Um worker por tipo, com base comum, duas imagens e extração em JSON no bucket |
| [ADR-008](adr-008-observabilidade.md) | Observabilidade no padrão do Agnes Collector, com logs em JSON |
| [ADR-009](adr-009-virada-unica-pelos-consumidores.md) | Virada única pelos consumidores, sem chave de ambiente |

## Infra

[infra.md](infra.md): banco, fila, bucket, cluster, autenticação, imagens, rede, recursos e observabilidade, com o que já está definido e o que ainda sai de cada atividade.

## Como usar

- Consulte o ADR antes de mudar algo que ele cobre.
- Uma decisão nova vira um ADR novo. Uma decisão que muda substitui a antiga: o ADR antigo fica com status **Substituído pelo ADR-NNN**.
- Detalhes que a implementação fixar (regra do cálculo de status, validação do token, nomes de variáveis) entram no ADR ou no `infra.md` correspondente, no mesmo commit da documentação.
- Formato e padrões seguem os do Agnes Collector (`agnes-collector`, `docs/arquitetura/`), traduzidos para Python (plano, §3.12).
