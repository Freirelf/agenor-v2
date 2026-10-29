# Padrões de desenvolvimento

- **Status:** aprovado pelo Lucas em 29/10.
- **O que é:** como uma mudança sai da ideia e chega ao commit: a sequência de trabalho, o que conta como pronto, como versionar, revisar e documentar. O padrão do código em si está em [arquitetura/padroes-de-codigo.md](arquitetura/padroes-de-codigo.md); a arquitetura, em [arquitetura/visao-geral.md](arquitetura/visao-geral.md).

## Sequência de uma atividade

O plano dá a direção; cada atividade (ou tarefa do Squads) é uma parte pequena, feita até o fim antes da próxima.

1. **Analisar** o que o plano e os ADRs pedem para ela.
2. **Verificar no código** o que existe de fato: o que reaproveitar, o que está quebrado, o que o plano não previu.
3. **Planejar** a execução e combinar com o Lucas antes de mudar a direção do plano, de um ADR ou do modelo de dados.
4. **Executar** no padrão de código, com testes junto.
5. **Validar** com o `verify.sh` e, quando couber, no ambiente local (`local/`).

Uma tarefa nova do Squads começa numa sessão nova, a partir do status no topo do plano e do **Próximo:** do contexto.

## Pronto quando

Uma atividade só está pronta quando:

- o comportamento pedido funciona e tem teste, inclusive o caso de erro;
- o `scripts/agent/verify.sh` do repositório está verde (formatação, lint, tipos e testes);
- o que toca banco passou pelo `revisor-isolamento-banco`, e o modelo bate com o `modelo-de-dados.md`;
- o que muda o contrato atualizou o `agenor-common` e o OpenAPI gerado;
- quando a atividade mexe no fluxo entre serviços, ele foi exercitado no `local/` (`check.sh`);
- a documentação foi atualizada (abaixo);
- o Lucas viu o que entra em cada commit e confirmou.

## Documentação: o que vai onde

| Mudou… | Atualize |
|---|---|
| Status de uma atividade, ordem, escopo, risco | `docs/PLANO_AGENOR_2_0.md` (status no topo e §6) |
| O que foi feito e decidido no dia | `docs/CONTEXTO_E_DECISOES.md`, terminando em **Próximo:** |
| Uma decisão técnica | O ADR dela (linha "Atualizado") ou um ADR novo |
| Tabela, coluna ou índice | `docs/arquitetura/modelo-de-dados.md`, antes do código |
| O que o código precisa do ambiente | `docs/arquitetura/infra.md` |
| Comandos ou armadilhas de um repositório | O `AGENTS.md` dele |
| Um procedimento que se repete | Uma skill em `.claude/skills/` |

Documentos em português, frases curtas, sem prazo nem data de entrega (os prazos estão no Squads).

## Git

- **Um repositório por serviço** (ver o `AGENTS.md` da raiz). Mudança que atravessa repositórios vira um commit em cada um; a raiz só recebe documentação, `local/`, `scripts/agent/` e `.claude/`.
- **Branch `main`, commits pequenos e completos:** cada commit passa no `verify.sh` sozinho. Quando entrar outra pessoa ou o CI do cliente, passa a ser uma branch por tarefa do Squads, com PR.
- **Mensagem:** a atividade na frente e o que muda, em português (`A1.6: itens idempotentes e itens já concluídos`). No corpo, tópicos com o que não é óbvio pelo diff. Commit só de formatação ou de renomeação fica separado do commit de comportamento.
- **Commit e push só com a confirmação do Lucas.** Antes, mostre o que entra em cada commit, por repositório.

## Revisão

- **`revisor-isolamento-banco`** em toda mudança de `alembic/`, `app/models/`, `app/repositories/` ou SQL do DC.
- **Revisão de código** (`/code-review`) antes de commitar uma atividade inteira ou uma mudança grande em lógica concorrente (despachante, travas, retentativa).
- Achado da revisão é corrigido antes do commit, ou registrado no contexto com o motivo de ficar para depois.

## Dependências

- `uv add` com faixa de versão; o `uv.lock` vai no commit.
- Dependência nova só com motivo (o que ela resolve que a biblioteca padrão ou uma que já usamos não resolve), anotado no commit.
- O `agenor-common` entra por caminho (`../agenor-common`) até existir a tag Git; depois, por tag.

## Segurança

- Nenhuma credencial no código, nos values, nos commits ou na saída de comandos. Segredo é `SecretStr`, e erro de validação não mostra valor.
- Não leia nem copie arquivos `.env`. Se um segredo aparecer numa saída, avise o Lucas.
- Infra é do cliente: não altere `bitbucket-pipelines.yml`, `sonar-project.properties`, `helm/`, `kubernetes/` nem values. Um problema neles vira alerta (§3.10 do plano).

## Ambiente local primeiro

Tudo é desenvolvido e validado localmente (`local/`: Postgres, S3 local, DC atual e cluster kind). Os ambientes do cliente são a última etapa (fase 6).
