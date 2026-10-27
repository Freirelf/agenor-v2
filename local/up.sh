#!/usr/bin/env bash
# Sobe o ambiente local do Agenor 2.0 (A0.5): cluster kind, Postgres, S3 local e o DC atual.
# Idempotente: rodar de novo só recria o que faltar. No fim, roda o check.sh.
set -euo pipefail
cd "$(dirname "$0")"
root=$(cd .. && pwd)

CLUSTER=agenor
# "Ponto de partida: DC atual da staging (8d2212f)" no agenor-document-collector.
DC_ATUAL_COMMIT=fdd4c55

need() {
  command -v "$1" >/dev/null || { echo "falta o $1: $2"; exit 1; }
}
need docker "OrbStack ou Docker Desktop"
need kind "brew install kind"
need kubectl "vem com o OrbStack (~/.orbstack/bin) ou brew install kubernetes-cli"
need openssl "vem com o macOS"

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  kind create cluster --config kind.yaml
fi

mkdir -p .generated

# DC atual: o commit de partida, sem alterações, separado do código do DC v2 (que muda).
dc=.generated/dc-atual
if [ "$(cat "$dc/.commit" 2>/dev/null)" != "$DC_ATUAL_COMMIT" ]; then
  rm -rf "$dc"
  mkdir -p "$dc"
  git -C "$root/agenor-document-collector" archive "$DC_ATUAL_COMMIT" | tar -x -C "$dc"
  echo "$DC_ATUAL_COMMIT" >"$dc/.commit"
fi

# Chave RSA descartável: o DC atual cria um cliente da OCI Queue no import e exige uma chave
# válida. O endpoint da fila é inalcançável (compose.yaml), então a chave nunca é usada.
if [ ! -f .generated/oci.env ]; then
  key=$(openssl genrsa 2048 2>/dev/null)
  fingerprint=$(openssl rsa -pubout -outform DER 2>/dev/null <<<"$key" | openssl md5 -c | awk '{print $NF}')
  # Uma linha só, com \n literais: o DC atual troca "\n" por quebra de linha ao ler a chave.
  printf 'OCI_KEY_FILE=%s\nOCI_FINGERPRINT=%s\n' "$(awk '{printf "%s\\n", $0}' <<<"$key")" "$fingerprint" \
    >.generated/oci.env
fi

docker compose up -d --build --wait

./check.sh
