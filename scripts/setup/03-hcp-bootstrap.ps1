# =============================================================================
# Bootstrap HCP — IAM (SP + WIF). Bucket/canais criados no 1o packer build.
# Uso: .\03-hcp-bootstrap.ps1
# =============================================================================

$ErrorActionPreference = "Stop"
$cfg = & (Join-Path $PSScriptRoot "config.ps1")

$GitHubOrg    = $cfg.GitHubOrg
$GitHubRepo   = $cfg.GitHubRepo
$HcpProjectId = $cfg.HcpProjectId
$HcpOrgId     = $cfg.HcpOrgId
$BucketName   = $cfg.HcpBucketName
$SpName       = $cfg.HcpSpName
$ProviderName = $cfg.HcpWifName
$SpResource   = "iam/project/$HcpProjectId/service-principal/$SpName"

Write-Host "`n=== Bootstrap HCP (IAM) ===" -ForegroundColor Cyan
Write-Host "Org: $HcpOrgId | Project: $HcpProjectId | Repo: $GitHubOrg/$GitHubRepo`n"

if (-not (Get-Command hcp -ErrorAction SilentlyContinue)) {
    Write-Error "HCP CLI nao encontrado."
}

if (-not (hcp auth print-access-token 2>$null)) {
    Write-Error "Execute: hcp auth login"
}

hcp profile set organization_id $HcpOrgId | Out-Null
hcp profile set project_id $HcpProjectId | Out-Null

# Service Principal
Write-Host ">> Service Principal..." -ForegroundColor Cyan
hcp iam service-principals describe $SpName --project $HcpProjectId 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] SP '$SpName' ja existe" -ForegroundColor Green
} else {
    hcp iam service-principals create $SpName --project $HcpProjectId
    if ($LASTEXITCODE -ne 0) { throw "Falha ao criar SP" }
    Write-Host "[OK] SP '$SpName' criado" -ForegroundColor Green
}

# WIF GitHub
Write-Host ">> WIF GitHub..." -ForegroundColor Cyan
hcp iam workload-identity-providers describe $ProviderName --project $HcpProjectId 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] WIF '$ProviderName' ja existe" -ForegroundColor Green
} else {
    hcp iam workload-identity-providers create-oidc $ProviderName `
        --service-principal=$SpResource `
        --issuer="https://token.actions.githubusercontent.com" `
        --conditional-access="jwt_claims.repository_owner == `"$GitHubOrg`"" `
        --allowed-audience="https://github.com/$GitHubOrg" `
        --description="GitHub Actions $GitHubRepo"
    if ($LASTEXITCODE -ne 0) { throw "Falha ao criar WIF" }
    Write-Host "[OK] WIF '$ProviderName' criado" -ForegroundColor Green
}

# Bucket e canais: criados automaticamente no primeiro packer build
Write-Host ""
Write-Host ">> Bucket '$BucketName' e canais (dev/hml/prod):" -ForegroundColor Cyan
Write-Host "   Serao criados no HCP Portal no primeiro 'packer build'." -ForegroundColor Yellow
Write-Host "   Canais dev/hml/prod: crie manualmente no portal apos o 1o build." -ForegroundColor Yellow
Write-Host "   https://portal.cloud.hashicorp.com/services/packer" -ForegroundColor Yellow

$outDir = Join-Path $PSScriptRoot "output"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
@{
    hcp_project_id                 = $HcpProjectId
    hcp_bucket_name                = $BucketName
    hcp_service_principal          = $SpName
    hcp_workload_identity_provider = $ProviderName
    github_org                     = $GitHubOrg
    github_repo                    = $GitHubRepo
} | ConvertTo-Json | Set-Content (Join-Path $outDir "hcp-bootstrap.json") -Encoding UTF8

Write-Host "`n=== HCP IAM concluido ===" -ForegroundColor Green
Write-Host "Secrets GitHub (se ainda nao configurados):"
Write-Host "  HCP_WORKLOAD_IDENTITY_PROVIDER = $ProviderName"
Write-Host "  HCP_SERVICE_PRINCIPAL            = $SpName"
