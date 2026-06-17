# =============================================================================
# Sandbox Microsoft Learn — build local sem subscription propria
# Uso: .\sandbox-run.ps1
# =============================================================================

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$SandboxDir  = Join-Path $ProjectRoot "sandbox"

Write-Host ""
Write-Host "=== Image Factory — Sandbox Microsoft Learn ===" -ForegroundColor Cyan
Write-Host "Tempo limite do sandbox: ~1 hora. Comece ja!`n"

if (-not (Get-Command packer -ErrorAction SilentlyContinue)) {
    Write-Host "Instalando Packer..." -ForegroundColor Yellow
    winget install Hashicorp.Packer --accept-package-agreements --accept-source-agreements
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}

Write-Host ">> Verificando login Azure..." -ForegroundColor Cyan
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host ""
    Write-Host "Faca login no tenant do SANDBOX (Concierge subscription):" -ForegroundColor Yellow
    Write-Host "  1. https://learn.microsoft.com/training/modules/create-linux-virtual-machine-in-azure/3-1-exercise-create-virtual-machine" -ForegroundColor White
    Write-Host "  2. Clique em 'Activate sandbox'" -ForegroundColor White
    Write-Host "  3. Anote o Resource Group learn-... no portal" -ForegroundColor White
    Write-Host ""
    az login --use-device-code
    $account = az account show | ConvertFrom-Json
}

$subName = $account.name
Write-Host "[OK] Subscription: $subName ($($account.id))" -ForegroundColor Green

if ($subName -notlike "*Concierge*" -and $subName -notlike "*Learn*") {
    Write-Host "[AVISO] Troque para Concierge subscription no portal Azure" -ForegroundColor Yellow
}

Write-Host ""
Write-Host ">> Resource Groups learn-*:" -ForegroundColor Cyan
az group list --query "[?starts_with(name,'learn')].{Name:name, Location:location}" -o table

$learnRg = Read-Host "`nCole o nome do RG (ex: learn-a1b2c3d4-...)"
if (-not $learnRg) { throw "RG obrigatorio" }

$location = az group show --name $learnRg --query location -o tsv
Write-Host "[OK] RG: $learnRg | Regiao: $location" -ForegroundColor Green

$varsFile = Join-Path $SandboxDir "sandbox.pkrvars.hcl"
@"
learn_resource_group = "$learnRg"
azure_location       = "$location"
image_version        = "1.0.0"
os_flavor            = "ubuntu-22-04"
"@ | Set-Content $varsFile -Encoding UTF8

$packerTarget = "sandbox-golden"
$useHcp = Read-Host "`nEnviar metadados ao HCP Packer? (s/N)"
if ($useHcp -eq "s" -or $useHcp -eq "S") {
    if (-not (Get-Command hcp -ErrorAction SilentlyContinue)) {
        throw "HCP CLI nao encontrado"
    }
    if (-not (hcp auth print-access-token 2>$null)) {
        throw "Execute: hcp auth login"
    }
    Write-Host "Crie chave SP: hcp iam service-principals keys create packer-ci-packer-golden" -ForegroundColor Yellow
    $env:HCP_CLIENT_ID = Read-Host "HCP_CLIENT_ID"
    $sec = Read-Host "HCP_CLIENT_SECRET" -AsSecureString
    $env:HCP_CLIENT_SECRET = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
    $env:HCP_PACKER_BUILD_FINGERPRINT = "sandbox.$(Get-Date -Format 'yyyyMMddHHmmss')"
    $packerTarget = "sandbox-golden-hcp"
}

Write-Host ""
Write-Host ">> Packer build -only=$packerTarget (~15-20 min)..." -ForegroundColor Cyan
Push-Location $SandboxDir
try {
    packer init .
    packer validate -var-file=sandbox.pkrvars.hcl .
    packer build -only=$packerTarget -var-file=sandbox.pkrvars.hcl .
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "=== Build concluido ===" -ForegroundColor Green
Write-Host "  az image list --resource-group $learnRg -o table"
