#!/usr/bin/env bash
# DC v2 no kind (A1.4): constrói a imagem, carrega no cluster, roda o Job de migração e, só se ele
# terminar bem, sobe o Deployment. No fim, confere o health de dentro do cluster.
# Exige o local/ no ar (local/up.sh): o banco é o mesmo do compose.
set -euo pipefail
cd "$(dirname "$0")"
root=$(cd .. && pwd)

NS=agenor
IMAGE=agenor-local/dc-v2:dev
MANIFEST=k8s/dc-v2.yaml

# Só os documentos do manifesto de um kind (ou, com "!", todos menos esses).
docs() {
  awk -v want="$1" 'BEGIN { RS = "\n---\n"; neg = sub(/^!/, "", want) }
    { hit = ($0 ~ ("\nkind: (" want ")\n")) }
    (neg && !hit) || (!neg && hit) { print "---"; print }' "$MANIFEST"
}

docker build -q --build-context agenor-common="$root/agenor-common" -t "$IMAGE" "$root/agenor-document-collector" >/dev/null
# kind load docker-image falha com imagens multiplataforma no OrbStack; o arquivo funciona sempre.
mkdir -p .generated
docker save "$IMAGE" -o .generated/dc-v2.tar
kind load image-archive .generated/dc-v2.tar --name agenor >/dev/null
echo "ok     imagem $IMAGE carregada no kind"

docs '!Job|Deployment' | kubectl --context kind-agenor apply -f - >/dev/null

kubectl --context kind-agenor -n "$NS" delete job dc-v2-migrate --ignore-not-found --wait >/dev/null
docs 'Job' | kubectl --context kind-agenor apply -f - >/dev/null
if ! kubectl --context kind-agenor -n "$NS" wait job/dc-v2-migrate --for=condition=Complete --timeout=180s >/dev/null; then
  echo "FALHOU migração (Job dc-v2-migrate):"
  kubectl --context kind-agenor -n "$NS" logs job/dc-v2-migrate --tail=30 | sed 's/^/       /'
  exit 1
fi
echo "ok     migração (Job dc-v2-migrate) concluída"

docs 'Deployment' | kubectl --context kind-agenor apply -f - >/dev/null
kubectl --context kind-agenor -n "$NS" rollout restart deployment/dc-v2 >/dev/null
kubectl --context kind-agenor -n "$NS" rollout status deployment/dc-v2 --timeout=180s >/dev/null
echo "ok     Deployment dc-v2 pronto"

kubectl --context kind-agenor -n "$NS" delete pod dc-v2-check --ignore-not-found --wait >/dev/null
kubectl --context kind-agenor -n "$NS" run dc-v2-check --restart=Never --image=curlimages/curl:8.14.1 --command -- \
  curl -fsS -o /dev/null -w 'health HTTP %{http_code}\n' http://dc-v2:9092/api/v1/health/ >/dev/null
kubectl --context kind-agenor -n "$NS" wait pod/dc-v2-check --for=jsonpath='{.status.phase}'=Succeeded --timeout=120s >/dev/null
echo "ok     de dentro do cluster: $(kubectl --context kind-agenor -n "$NS" logs dc-v2-check)"
kubectl --context kind-agenor -n "$NS" delete pod dc-v2-check --wait=false >/dev/null
