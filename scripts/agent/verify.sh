#!/usr/bin/env bash
# Roda o scripts/agent/verify.sh de cada repositório e resume. Sai com 1 se algum falhar.
set -uo pipefail
cd "$(dirname "$0")/../.."

repos=(agenor-common agenor-launcher agenor-workers agenor-document-collector)
failed=()

for repo in "${repos[@]}"; do
  echo "== $repo"
  if [ ! -x "$repo/scripts/agent/verify.sh" ]; then
    echo "FALHOU sem scripts/agent/verify.sh"
    failed+=("$repo")
  elif ! "$repo/scripts/agent/verify.sh"; then
    failed+=("$repo")
  fi
done

echo
if [ ${#failed[@]} -eq 0 ]; then
  echo "verify: todos os repositórios ok"
else
  echo "verify: falhou em ${failed[*]}"
  exit 1
fi
