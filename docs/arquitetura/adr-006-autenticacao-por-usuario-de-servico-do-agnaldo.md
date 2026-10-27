# ADR-006: Autenticação entre serviços por usuários de serviço do Agnaldo

- **Status:** Aceito (o mecanismo de validação no DC é confirmado na A1.2)
- **Data:** 2026-10-27
- **Origem:** plano, §3.2 ("Autenticação"), §3.7, §3.12 (mudança 2) e §3.13, item 15

## Contexto

- Nenhum callback do DC atual tem autenticação. Existe um header de bypass e a identificação só por `X-User-ID`.
- O worker já precisa se autenticar no Agnaldo para pegar a sessão e-CAC.
- O Agnes Collector usa o Agnaldo para sessões e login, mas identifica o agente no Collector com `base64(agent_id)`, que não é autenticação.
- Já existem usuários de serviço do Agnaldo para os outros produtos.

## Decisão

- Cada serviço (Launcher e workers) tem um **usuário de serviço no Agnaldo**: uma credencial por serviço, vinda de Secret.
- O serviço obtém o token com `POST /auth/token` e o guarda **em memória**, renovando com folga de 5 min antes de expirar. Nada em disco.
- O worker usa o **mesmo token** para o Agnaldo (sessão e-CAC) e para o DC.
- O DC valida o token em **toda chamada** das APIs novas, numa dependência do FastAPI, e confere se o usuário pode chamar aquela API (worker ou Launcher).
- As chamadas dos consumidores continuam chegando pelo Agnaldo/APISIX, com o token do usuário final.

**Em aberto (A1.2):** como o DC valida o token. As opções são a chave pública do realm (validação local do JWT) ou `GET /auth/users/me` com cache curto. A escolha entra aqui quando for confirmada.

## Alternativas consideradas

- **Clients no Keycloak por serviço.** Foi a primeira versão (26/10). Exige configuração nova no Keycloak do cliente; os usuários de serviço do Agnaldo já existem. Trocada na §3.12, com aprovação explícita.
- **Segredo compartilhado (header fixo).** Uma credencial vazada vale para todos, e não identifica quem chamou.
- **`base64(agent_id)`, como no Agnes Collector.** Não autentica.
- **mTLS no cluster.** Depende de malha de serviço que o cliente não tem.

## Consequências

- A validação do token é risco do início da fase 1 (§3.13, item 15): sem ela, a API nova não fecha.
- O Agnaldo passa a ser dependência do DC para autorizar o worker e o Launcher. Com validação local do JWT, a dependência fica só na chave pública.
- Cada ambiente precisa de usuários de serviço para o Launcher e os workers (pedido 6).
