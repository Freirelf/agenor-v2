#!/usr/bin/env bash
# PostToolUse (Edit/Write): roda ruff format e ruff check --fix no .py editado, com o ruff e a
# configuração do repositório dele. Pula repositórios sem [tool.ruff] no pyproject.toml (desde
# 28/10, os cinco têm).
# Erros que o --fix não resolve voltam ao modelo com exit 2.
set -uo pipefail

file=$(jq -r '.tool_input.file_path // empty')
[[ "$file" == *.py && -f "$file" ]] || exit 0

root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
case "$file" in "$root"/*) ;; *) exit 0 ;; esac

# pyproject.toml mais próximo, sem sair da pasta do projeto
dir=$(dirname "$file")
while [ "$dir" != "$root" ] && [ "$dir" != "/" ] && [ ! -f "$dir/pyproject.toml" ]; do
  dir=$(dirname "$dir")
done
[ -f "$dir/pyproject.toml" ] && grep -q '^\[tool\.ruff' "$dir/pyproject.toml" || exit 0

cd "$dir" || exit 0
uv run --quiet ruff format --quiet "$file" >/dev/null 2>&1
if ! out=$(uv run --quiet ruff check --fix --quiet "$file" 2>&1); then
  echo "ruff check em ${file#"$root"/}:" >&2
  echo "$out" >&2
  exit 2
fi
exit 0
