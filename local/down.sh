#!/usr/bin/env bash
# Para o ambiente local. Sem argumento, os dados do banco e do S3 e o cluster continuam.
# Com --all, apaga também os volumes (banco e S3 locais) e o cluster kind.
set -euo pipefail
cd "$(dirname "$0")"

if [ "${1:-}" = "--all" ]; then
  docker compose down -v
  kind delete cluster --name agenor
else
  docker compose stop
fi
