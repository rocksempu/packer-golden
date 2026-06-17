# =============================================================================
# Bootstrap GitHub — configura secrets e variables no repositório
#
# Uso:
#   .\scripts\setup\02-github-bootstrap.ps1 -GitHubOrg "sua-org" -GitHubRepo "seu-repo"
#
# Pré-requisitos:
#   - gh auth login (GitHub CLI autenticado)
#   - 01-azure-bootstrap.ps1 já executado (gera output/azure-bootstrap.json)
# =============================================================================

param(
    [string]$GitHubOrg = "",
    [string]$GitHubRepo = "",
    [string]$HcpWorkloadIdentityProvider = "",
    [string]$HcpServicePrincipal = ""
)

$ErrorActionPreference = "Stop"

$cfg = & (Join-Path $PSScriptRoot "config.ps1")
if (-not $GitHubOrg)  { $GitHubOrg  = $cfg.GitHubOrg }
if (-not $GitHubRepo) { $GitHubRepo = $cfg.GitHubRepo }
if (-not $HcpWorkloadIdentityProvider) { $HcpWorkloadIdentityProvider = $cfg.HcpWifName }
if (-not $HcpServicePrincipal)         { $HcpServicePrincipal         = $cfg.HcpSpName }
$Repo = "$GitHubOrg/$GitHubRepo"

Write-Host "`n=== Image Factory — Bootstrap GitHub ===" -ForegroundColor Cyan
Write-Host "Repo: $Repo`n"

# --- Verificar gh CLI ---
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI nao encontrado. Instale: https://cli.github.com/"
}

$ghAuth = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Faca login no GitHub CLI:" -ForegroundColor Yellow
    gh auth login
}

# --- Carregar output do Azure bootstrap ---
$bootstrapFile = Join-Path $PSScriptRoot "output/azure-bootstrap.json"
if (-not (Test-Path $bootstrapFile)) {
    Write-Error "Arquivo nao encontrado: $bootstrapFile`nExecute primeiro: .\scripts\setup\01-azure-bootstrap.ps1"
}

$cfg = Get-Content $bootstrapFile | ConvertFrom-Json

# --- Secrets ---
Write-Host ">> Configurando Secrets..." -ForegroundColor Cyan

$secrets = @{
    "AZURE_SUBSCRIPTION_ID" = $cfg.azure_subscription_id
    "AZURE_TENANT_ID"       = $cfg.azure_tenant_id
    "AZURE_CLIENT_ID"       = $cfg.azure_client_id
}

if ($HcpWorkloadIdentityProvider) {
    $secrets["HCP_WORKLOAD_IDENTITY_PROVIDER"] = $HcpWorkloadIdentityProvider
}
if ($HcpServicePrincipal) {
    $secrets["HCP_SERVICE_PRINCIPAL"] = $HcpServicePrincipal
}

foreach ($key in $secrets.Keys) {
    gh secret set $key --body $secrets[$key] --repo $Repo
    Write-Host "[OK] Secret: $key" -ForegroundColor Green
}

if (-not $HcpWorkloadIdentityProvider) {
    Write-Host "[PENDENTE] HCP_WORKLOAD_IDENTITY_PROVIDER — configure apos setup HCP (Fase 2)" -ForegroundColor Yellow
    Write-Host "[PENDENTE] HCP_SERVICE_PRINCIPAL — configure apos setup HCP (Fase 2)" -ForegroundColor Yellow
}

# --- Variables ---
Write-Host "`n>> Configurando Variables..." -ForegroundColor Cyan

$variables = @{
    "AZURE_BUILD_RESOURCE_GROUP" = $cfg.azure_build_resource_group
    "AZURE_SIG_RESOURCE_GROUP"     = $cfg.azure_sig_resource_group
    "AZURE_SIG_GALLERY_NAME"       = $cfg.azure_sig_gallery_name
    "AZURE_SIG_IMAGE_DEFINITION"   = $cfg.azure_sig_image_definition
    "AZURE_LOCATION"               = $cfg.azure_location
    "HCP_PACKER_BUCKET_NAME"       = "base-images"
}

foreach ($key in $variables.Keys) {
    gh variable set $key --body $variables[$key] --repo $Repo
    Write-Host "[OK] Variable: $key = $($variables[$key])" -ForegroundColor Green
}

# --- Environments ---
Write-Host "`n>> Criando Environments..." -ForegroundColor Cyan
foreach ($env in @("dev", "hml", "prod")) {
    gh api --method PUT "repos/$Repo/environments/$env" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Environment: $env" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Environment $env — verifique permissoes no repo" -ForegroundColor Yellow
    }
}

Write-Host "`n=== GitHub bootstrap concluido ===" -ForegroundColor Green
Write-Host "Verifique em: https://github.com/$Repo/settings/secrets/actions"
