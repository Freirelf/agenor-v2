# ADR-006: Autenticação entre serviços por usuários de serviço do Agnaldo

- **Status:** Aceito (validação no DC confirmada na A1.2, em 28/10)
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

### Validação no DC (A1.2, 28/10)

A sondagem com um usuário de serviço real (`scripts/sondar_token_agnaldo.py` do DC) mostrou:

- `POST /api/v1/auth/token` espera **formulário** (`username`, `password`), não JSON, e devolve `access_token`, `expires_in` (5 h), `refresh_token` e `refresh_expires_in`.
- O `access_token` é um **JWT RS256 do Keycloak** do SSO da Agnes (`iss = https://sso.agnes.com.br/realms/agnes`, `azp = plataforma`, `aud = account`), com `kid`. O JWKS do realm é público.
- O token **não traz papel do serviço**: só os papéis padrão do realm. `GET /api/v1/auth/users/me` existe, mas exigiria uma chamada ao Agnaldo por requisição.

**Decisão:** o DC valida o JWT **localmente**, pelo JWKS do realm (`app/auth.py`):

- assinatura RS256 pelas chaves do JWKS, em cache, buscadas de novo quando aparece um `kid` desconhecido;
- `iss` igual a `AUTH_ISSUER`, com `exp` e `iat` obrigatórios e 30 s de tolerância de relógio. O `aud` (`account`, genérico) não é conferido;
- **autorização por lista** de `preferred_username` por API: `AUTH_WORKER_USERS` e `AUTH_LAUNCHER_USERS`. Um usuário fora da lista recebe 403 (`SERVICE_NOT_ALLOWED`); token ausente, inválido ou expirado, 401 (`TOKEN_MISSING`, `TOKEN_INVALID`, `TOKEN_EXPIRED`); JWKS fora do ar, 503.

O `/auth/users/me` fica descartado: põe o Agnaldo no caminho de toda chamada e não traz nada que a lista não resolva. Validado contra o SSO real em 28/10 (`tests/test_auth_agnaldo_real.py`, opcional).

## Alternativas consideradas

- **Clients no Keycloak por serviço.** Foi a primeira versão (26/10). Exige configuração nova no Keycloak do cliente; os usuários de serviço do Agnaldo já existem. Trocada na §3.12, com aprovação explícita.
- **Segredo compartilhado (header fixo).** Uma credencial vazada vale para todos, e não identifica quem chamou.
- **`base64(agent_id)`, como no Agnes Collector.** Não autentica.
- **mTLS no cluster.** Depende de malha de serviço que o cliente não tem.

## Consequências

- A validação do token era risco do início da fase 1 (§3.13, item 15). Fechada na A1.2 (28/10).
- O DC depende só do JWKS público do SSO, não do Agnaldo, para autorizar o worker e o Launcher.
- Um usuário de serviço novo exige incluir o nome na lista do DC (configuração, sem código).
- Se o realm mudar de emissor, muda o `AUTH_ISSUER` de cada ambiente.
- Cada ambiente precisa de usuários de serviço para o Launcher e os workers (pedido 6).
