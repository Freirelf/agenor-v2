# ADR-005: O Launcher cria um Kubernetes Job por tentativa

- **Status:** Aceito
- **Data:** 2026-10-27
- **Origem:** plano, §2 ("Launcher"), §3.0 e §3.3

## Contexto

Hoje o scraper consome a fila direto, com 6 réplicas fixas e uma coleta por réplica. Uma coleta pode durar horas (a mensagem é renovada por até 4 h), e um coletor travado ocupa a réplica. No alinhamento de 26/10 o cliente pediu um componente que suba um pod por coleta e o derrube no fim (modelo inspirado em AWS Lambda).

## Decisão

**Serviço próprio, sem banco.** O estado fica no DC (tentativas) e no Kubernetes (Jobs).

### Catálogo de tipos

Arquivo de configuração versionado com o Launcher. Para cada tipo de coleta:

- imagem e comando (`python -m workers.<tipo>`);
- CPU e memória;
- tempo máximo;
- configuração específica do tipo (variáveis não sensíveis e os Secrets que ele monta).

O limite de concorrência por tipo é do DC ([ADR-004](adr-004-despachante-e-retentativa.md)), não do catálogo.

### Consumo

Consome tudo o que chega. Mantém só um **teto de segurança** de Jobs ativos no namespace: acima dele, não cria o Job e deixa a mensagem voltar para a fila.

### Criação

Um **Kubernetes Job** por tentativa:

| Campo | Valor |
|---|---|
| nome | determinístico, a partir do tipo e do `attempt_id` |
| `backoffLimit` | `0`: quem decide retentativa é o DC |
| `activeDeadlineSeconds` | tempo máximo do tipo, do catálogo |
| `ttlSecondsAfterFinished` | limpeza automática |
| `restartPolicy` | `Never` |
| labels | tipo, `attempt_id`, `collected_id` |
| env | `ATTEMPT_ID`, `COLLECTED_ID`, `COLLECTION_TYPE` e a configuração do tipo ([ADR-003](adr-003-contratos.md)) |

### Confirmação da mensagem

A mensagem é apagada **depois que o Job é criado**. Se o Launcher cair entre criar e apagar, a mensagem volta, a criação devolve "já existe" (nome determinístico) e ela é apagada. Sem duplicidade. Mensagem com versão desconhecida ou inválida é apagada e registrada em log.

### Acompanhamento

Observa os Jobs e informa ao DC, em todos os casos, como cada um terminou: sucesso, falha, prazo estourado, falta de memória ou imagem inexistente (`POST /attempts/{id}/infra-event`). O DC decide o que fazer.

### Reinício e réplicas

- Ao subir, reconcilia os Jobs existentes (informa os que terminaram enquanto estava fora) antes de consumir.
- Uma réplica basta no início: a fila segura os pedidos e todas as operações são idempotentes. Alta disponibilidade (duas réplicas com eleição de líder) fica para depois.

## Alternativas consideradas

- **Pod solto, sem Job.** Teríamos de reimplementar prazo, limpeza e o registro de como terminou.
- **Deployments por tipo com réplicas fixas** (modelo atual e o da fase 5 do Agnes Collector). Mantém recursos ociosos e um coletor travado continua ocupando a réplica.
- **Knative, KEDA ou outro operador.** Mais infra para o cliente operar, sem ganho sobre um Job para execuções longas e esporádicas.
- **Launcher com banco próprio.** Duplicaria o estado que já está no DC e no Kubernetes.

## Consequências

- O Launcher precisa de uma ServiceAccount que crie, liste, observe e apague Jobs e pods, e leia logs, **só no namespace dos workers** (pedido 2 ao cliente).
- Cada tentativa paga o tempo de subir um pod, irrelevante perto da duração de uma coleta.
- O namespace precisa de ResourceQuota e de capacidade de nós para os picos (pedidos 1 e 8).
- Os logs dos Jobs somem com o `ttlSecondsAfterFinished`: precisam ser coletados pelo cliente (pedido 13).
