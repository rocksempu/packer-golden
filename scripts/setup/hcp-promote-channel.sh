#!/usr/bin/env bash
# Promove uma versão (fingerprint) para um canal HCP Packer via API REST.
# O HCP CLI não expõe subcomando "hcp packer" — use este script no CI.
set -euo pipefail

BUCKET="${1:?usage: hcp-promote-channel.sh <bucket> <channel> [version_fingerprint]}"
CHANNEL="${2:?usage: hcp-promote-channel.sh <bucket> <channel> [version_fingerprint]}"
FINGERPRINT="${3:-}"

HCP_ORG_ID="${HCP_ORG_ID:?HCP_ORG_ID required}"
HCP_PROJECT_ID="${HCP_PROJECT_ID:?HCP_PROJECT_ID required}"
BASE_URL="https://api.cloud.hashicorp.com/packer/2023-01-01/organizations/${HCP_ORG_ID}/projects/${HCP_PROJECT_ID}/buckets/${BUCKET}"

TOKEN="$(hcp auth print-access-token)"

if [ -z "${FINGERPRINT}" ]; then
  FINGERPRINT="$(curl -fsS \
    -H "Authorization: Bearer ${TOKEN}" \
    "${BASE_URL}/versions?pagination.page_size=1" \
    | jq -r '.versions[0].fingerprint // empty')"
fi

if [ -z "${FINGERPRINT}" ] || [ "${FINGERPRINT}" = "null" ]; then
  echo "Nenhuma versão encontrada no bucket '${BUCKET}'." >&2
  exit 1
fi

echo "Versão: ${FINGERPRINT}"

CHANNEL_CODE="$(curl -sS -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${TOKEN}" \
  "${BASE_URL}/channels/${CHANNEL}")"

if [ "${CHANNEL_CODE}" = "200" ]; then
  curl -fsS -X PATCH "${BASE_URL}/channels/${CHANNEL}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"version_fingerprint\":\"${FINGERPRINT}\",\"update_mask\":\"versionFingerprint\"}" \
    | jq -r '.channel.name // .channel // .'
else
  curl -fsS -X POST "${BASE_URL}/channels" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"${CHANNEL}\",\"version_fingerprint\":\"${FINGERPRINT}\"}" \
    | jq -r '.channel.name // .channel // .'
fi

echo "Canal '${CHANNEL}' atualizado com fingerprint ${FINGERPRINT}."
