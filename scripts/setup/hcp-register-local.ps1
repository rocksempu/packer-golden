# =============================================================================
# Registra iteracao no HCP Packer localmente (Docker — sem Azure)
# Uso: .\hcp-register-local.ps1
# =============================================================================

$ErrorActionPreference = "Stop"
$cfg = & (Join-Path $PSScriptRoot "config.ps1")
$HcpTestDir = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "hcp-test"

Write-Host ""
Write-Host "=== HCP Packer — registro local (sem Azure) ===" -ForegroundColor Cyan
Write-Host "Bucket: $($cfg.HcpBucketName)"
Write-Host "Portal: https://portal.cloud.hashicorp.com/org/rocksempu-org/packer`n"

if (-not (Get-Command packer -ErrorAction SilentlyContinue)) {
    winget install Hashicorp.Packer --accept-package-agreements --accept-source-agreements
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker obrigatorio. Abra o Docker Desktop."
}

docker info 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Docker nao esta rodando." }

# Credenciais HCP para o Packer
if (-not $env:HCP_CLIENT_ID -or -not $env:HCP_CLIENT_SECRET) {
    Write-Host "Packer precisa de chave do Service Principal HCP." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1) hcp auth login" -ForegroundColor White
    Write-Host "2) hcp iam service-principals keys create $($cfg.HcpSpName) --output-cred-file=hcp-creds.json" -ForegroundColor White
    Write-Host "   Use oauth.client_id e oauth.client_secret do JSON" -ForegroundColor White
    Write-Host ""
    $env:HCP_CLIENT_ID = Read-Host "HCP_CLIENT_ID"
    $sec = Read-Host "HCP_CLIENT_SECRET" -AsSecureString
    $env:HCP_CLIENT_SECRET = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
}

$env:HCP_PACKER_BUILD_FINGERPRINT = "local.$(Get-Date -Format 'yyyyMMddHHmmss')"
$env:HCP_PROJECT_ID = $cfg.HcpProjectId

Push-Location $HcpTestDir
try {
    packer init .
    packer validate .
    packer build -var "image_version=1.0.0-local" .
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "=== Registro enviado ao HCP Packer ===" -ForegroundColor Green
Write-Host "Abra: https://portal.cloud.hashicorp.com/org/rocksempu-org/packer"
Write-Host "Bucket: $($cfg.HcpBucketName) → Iterations"
