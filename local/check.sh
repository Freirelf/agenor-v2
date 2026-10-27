#!/usr/bin/env bash
# Confere o ambiente local: o banco com o esquema do DC atual, o DC atual respondendo, o S3 com o
# bucket e os pods do cluster alcançando o DC e o S3. Sai com 1 se algum item falhar.
set -uo pipefail
cd "$(dirname "$0")"

CTX=kind-agenor
CHECK_IMAGE=curlimages/curl:8.14.1
fail=0

check() {
  local name=$1
  shift
  local out
  if out=$("$@" 2>&1); then
    echo "ok     $name: $(tail -n 1 <<<"$out")"
  else
    echo "FALHOU $name"
    tail -n 15 <<<"$out" | sed 's/^/       /'
    fail=1
  fi
}

psql_local() {
  docker compose exec -T db psql -U agenor -d document_collector -tAc "$1"
}

check "banco: revisão do Alembic no public" psql_local "select version_num from public.alembic_version"
check "banco: tabelas do DC atual" \
  psql_local "select count(*) || ' tabelas no public' from information_schema.tables where table_schema = 'public'"
check "DC atual: health" curl -fsS http://127.0.0.1:9092/api/v1/health/
check "S3: bucket do Agenor" curl -fsS -o /dev/null -w 'HTTP %{http_code}' http://127.0.0.1:8333/hiperautomacao-agenor-local
check "cluster: nó pronto" kubectl --context "$CTX" wait --for=condition=Ready node --all --timeout=60s
pod_reaches_services() {
  kubectl --context "$CTX" delete pod agenor-check --ignore-not-found --wait >/dev/null
  kubectl --context "$CTX" run agenor-check --restart=Never --image="$CHECK_IMAGE" --command -- sh -c \
    'curl -fsS -o /dev/null http://dc-atual:9092/api/v1/health/ && curl -fsS -o /dev/null http://s3:8333/hiperautomacao-agenor-local && echo "DC atual e S3 alcançados de dentro do cluster"' \
    >/dev/null
  kubectl --context "$CTX" wait pod/agenor-check --for=jsonpath='{.status.phase}'=Succeeded --timeout=120s >/dev/null
  local status=$?
  kubectl --context "$CTX" logs agenor-check
  kubectl --context "$CTX" delete pod agenor-check --wait=false >/dev/null
  return $status
}
check "cluster: pod alcança o DC atual e o S3" pod_reaches_services

exit $fail
