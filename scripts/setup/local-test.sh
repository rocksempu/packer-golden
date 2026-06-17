#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPTS_DIR="${ROOT_DIR}/scripts"

CONTAINER_NAME="packer-golden-test"

echo ""
echo "=== Local Test (Linux runner) ==="
echo "Rodando provisioners em Ubuntu 22.04 via Docker."
echo ""

if ! command -v docker >/dev/null 2>&1; then
  echo "ERRO: docker nao encontrado."
  exit 1
fi

docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

docker run -d --name "${CONTAINER_NAME}" \
  --privileged \
  -v "${SCRIPTS_DIR}:/scripts:ro" \
  ubuntu:22.04 \
  sleep 3600 >/dev/null

run_script() {
  local script="$1"
  shift || true
  echo ""
  echo ">> ${script}"
  docker exec "${CONTAINER_NAME}" bash -lc "apt-get update -qq && $* bash /scripts/${script}"
}

cleanup() {
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

run_script "01-os-updates.sh"
run_script "02-hardening.sh" "export SSH_USERNAME=packer LOCAL_TEST=true;"
run_script "03-install-apps.sh" "export INSTALL_DOCKER=true INSTALL_AZURE_CLI=true INSTALL_MONITORING_AGENT=false INSTALL_EDR_AGENT=false;"

echo ""
echo ">> Metadados da imagem"
docker exec "${CONTAINER_NAME}" bash -lc "echo 'BUILD_VERSION=ci-local' | tee /etc/golden-image-version >/dev/null && echo 'MODE=github-actions' | tee -a /etc/golden-image-version >/dev/null && cat /etc/golden-image-version"

run_script "05-validate.sh" "export LOCAL_TEST=true;"

echo ""
echo "=== OK: scripts validados ==="

