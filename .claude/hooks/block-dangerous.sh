#!/usr/bin/env bash
# PreToolUse (Bash): bloqueia comandos perigosos com exit 2. O motivo vai para o stderr,
# que o Claude Code mostra ao modelo. Uso manual: echo '{"tool_input":{"command":"..."}}' | block-dangerous.sh
set -uo pipefail

cmd=$(jq -r '.tool_input.command // empty')
[ -z "$cmd" ] && exit 0

block() {
  echo "Bloqueado pelo hook do agenor-v2: $1" >&2
  exit 2
}

# git push --force (inclui -f, --force-with-lease e refspec com +), olhando só o trecho do push
push_args=$(tr ';&|' '\n\n\n' <<<"$cmd" | grep -E '(^|[[:space:]])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+push([[:space:]]|$)')
if [ -n "$push_args" ]; then
  if grep -Eq '[[:space:]](--force|--force-with-lease|-f|--mirror|--delete|-d)([=[:space:]]|$)|[[:space:]]\+[^[:space:]]+' <<<"$push_args"; then
    block "git push forçado ou destrutivo. Faça o push você mesmo, se for o caso."
  fi
fi

# rm -rf em alvos amplos (raiz, home, pasta atual ou acima, curinga solto)
if grep -Eq '(^|[;&|[:space:]])rm[[:space:]]+(-[a-zA-Z]*[rR][a-zA-Z]*[[:space:]]+)+(/|~/?|\$HOME/?|\./?|\.\./?|\*|/\*|~/\*|\./\*)([[:space:]]|$)' <<<"$cmd"; then
  block "rm recursivo em alvo amplo."
fi

# Leitura de .env (o .env.example e afins continuam liberados)
env_file='[^[:space:];&|]*\.env(-test|\.local)?(["'\'']|[[:space:];&|]|$)'
if grep -Eq "(^|[;&|[:space:]])(cat|less|more|head|tail|bat|grep|rg|awk|sed|strings|xxd|od|cp|source|\.)[[:space:]]+([^;&|]*[[:space:]])?$env_file" <<<"$cmd"; then
  block "leitura de arquivo .env. Credenciais ficam fora do contexto; use o .env.example."
fi

# kubectl e helm só em contexto local (kind-* ou k3d-*)
if grep -Eq '(^|[;&|[:space:]])(kubectl|helm)([[:space:]]|$)' <<<"$cmd"; then
  ctx=$(grep -Eo -- '--(kube-)?context[= ][^[:space:]]+' <<<"$cmd" | head -n 1 | sed -E 's/^--(kube-)?context[= ]//')
  if [ -z "$ctx" ]; then
    if grep -Eq 'KUBECONFIG=' <<<"$cmd"; then
      block "kubectl/helm com KUBECONFIG inline exige --context (ou --kube-context) kind-* ou k3d-*."
    fi
    ctx=$(kubectl config current-context 2>/dev/null || true)
  fi
  if ! grep -Eq '^(kind|k3d)-' <<<"$ctx"; then
    block "kubectl/helm fora de contexto local (contexto: '${ctx:-desconhecido}'). Use --context kind-* ou k3d-*."
  fi
fi

exit 0
