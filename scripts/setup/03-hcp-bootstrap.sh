# =============================================================================
# Bootstrap HCP Packer — rocksempu-org / projeto packer-golden
#
# Uso:
#   ./scripts/setup/03-hcp-bootstrap.sh
#   ./scripts/setup/03-hcp-bootstrap.sh rocksempu packer-golden
# =============================================================================

set -euo pipefail

GITHUB_ORG="${1:-rocksempu}"
GITHUB_REPO="${2:-packer-golden}"
HCP_PROJECT_ID="${HCP_PROJECT_ID:-1c7acb8d-7539-4a33-8d4d-5ab419faaa85}"
HCP_ORG_ID="${HCP_ORG_ID:-36728d8a-278b-44b1-af7d-462d60a11f6a}"
BUCKET_NAME="${HCP_BUCKET_NAME:-base-images}"
SP_NAME="${HCP_SP_NAME:-packer-ci-packer-golden}"
PROVIDER_NAME="${HCP_WIF_NAME:-GitHub-packer-golden}"

echo ""
echo "=== Image Factory — Bootstrap HCP Packer ==="
echo "Org:     rocksempu-org (${HCP_ORG_ID})"
echo "Project: ${HCP_PROJECT_ID}"
echo "Repo:    ${GITHUB_ORG}/${GITHUB_REPO}"
echo ""

if ! command -v hcp &>/dev/null; then
  echo "ERRO: HCP CLI nao encontrado."
  echo "Instale: winget install Hashicorp.HCP"
  exit 1
fi

if ! hcp auth print-access-token &>/dev/null; then
  echo "Faca login no HCP:"
  hcp auth login
fi

# Selecionar projeto correto
hcp config set project "${HCP_PROJECT_ID}" 2>/dev/null || true
echo "[OK] HCP Project: ${HCP_PROJECT_ID}"

# --- Bucket ---
echo ""
echo ">> Criando bucket HCP Packer..."
if hcp packer buckets describe "${BUCKET_NAME}" &>/dev/null; then
  echo "[OK] Bucket '${BUCKET_NAME}' ja existe"
else
  hcp packer buckets create "${BUCKET_NAME}" \
    --description "Image Factory Azure — golden images (rocksempu)"
  echo "[OK] Bucket '${BUCKET_NAME}' criado"
fi

# --- Canais ---
echo ""
echo ">> Criando canais dev / hml / prod..."
for ch in dev hml prod; do
  if hcp packer channels describe "${BUCKET_NAME}" "${ch}" &>/dev/null; then
    echo "[OK] Canal '${ch}' ja existe"
  else
    hcp packer channels create "${BUCKET_NAME}" "${ch}"
    echo "[OK] Canal '${ch}' criado"
  fi
done

# --- Service Principal HCP ---
echo ""
echo ">> Criando Service Principal HCP..."
if hcp iam service-principals describe "${SP_NAME}" --project "${HCP_PROJECT_ID}" &>/dev/null; then
  echo "[OK] SP '${SP_NAME}' ja existe"
else
  hcp iam service-principals create "${SP_NAME}" --project "${HCP_PROJECT_ID}"
  echo "[OK] SP '${SP_NAME}' criado"
fi

# Role no Packer
hcp iam service-principals update "${SP_NAME}" \
  --project "${HCP_PROJECT_ID}" \
  --assign-roles "roles/packer.bucket-contributor" 2>/dev/null || true

# --- WIF GitHub ---
echo ""
echo ">> Configurando WIF para GitHub..."
if hcp iam workload-identity-providers describe "${PROVIDER_NAME}" --project "${HCP_PROJECT_ID}" &>/dev/null; then
  echo "[OK] WIF '${PROVIDER_NAME}' ja existe"
else
  hcp iam workload-identity-providers create-oidc "${PROVIDER_NAME}" \
    --project "${HCP_PROJECT_ID}" \
    --issuer-uri "https://token.actions.githubusercontent.com" \
    --allowed-audiences "https://github.com/${GITHUB_ORG}" \
    --conditional-access "assertion.repository=='${GITHUB_ORG}/${GITHUB_REPO}'"
  echo "[OK] WIF '${PROVIDER_NAME}' criado"
fi

# --- Output ---
OUT_DIR="$(dirname "$0")/output"
mkdir -p "${OUT_DIR}"

cat > "${OUT_DIR}/hcp-bootstrap.json" <<EOF
{
  "hcp_org_id": "${HCP_ORG_ID}",
  "hcp_org_name": "rocksempu-org",
  "hcp_project_id": "${HCP_PROJECT_ID}",
  "hcp_bucket_name": "${BUCKET_NAME}",
  "hcp_service_principal": "${SP_NAME}",
  "hcp_workload_identity_provider": "${PROVIDER_NAME}",
  "github_org": "${GITHUB_ORG}",
  "github_repo": "${GITHUB_REPO}"
}
EOF

echo ""
echo "=== HCP bootstrap concluido ==="
echo ""
echo "Configure no GitHub:"
echo "  gh secret set HCP_WORKLOAD_IDENTITY_PROVIDER --body '${PROVIDER_NAME}' --repo ${GITHUB_ORG}/${GITHUB_REPO}"
echo "  gh secret set HCP_SERVICE_PRINCIPAL --body '${SP_NAME}' --repo ${GITHUB_ORG}/${GITHUB_REPO}"
