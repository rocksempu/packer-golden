# =============================================================================
# Bootstrap Azure — Image Factory
# Provisiona: RGs, SIG, Service Principal, OIDC para GitHub Actions
#
# Uso (PowerShell):
#   .\scripts\setup\01-azure-bootstrap.ps1 -GitHubOrg "sua-org" -GitHubRepo "seu-repo"
#
# Pré-requisito: az login (conta com permissão de criar SP e role assignments)
# =============================================================================

param(
    [string]$GitHubOrg = "",
    [string]$GitHubRepo = "",
    [string]$Location = "",
    [string]$Prefix = "",
    [string]$SubscriptionId = ""
)

$ErrorActionPreference = "Stop"

# Carregar config do projeto (rocksempu/packer-golden)
$cfg = & (Join-Path $PSScriptRoot "config.ps1")

if (-not $GitHubOrg)   { $GitHubOrg   = $cfg.GitHubOrg }
if (-not $GitHubRepo)  { $GitHubRepo  = $cfg.GitHubRepo }
if (-not $Location)    { $Location    = $cfg.AzureLocation }
if (-not $Prefix)      { $Prefix      = $cfg.AzurePrefix }

# --- Nomes derivados do prefixo ---
$RgFactory   = "rg-$Prefix-factory"
$RgBuild     = "rg-$Prefix-build"
$GalleryName = "${Prefix}Gallery"
$ImageDef    = $cfg.ImageDef
$SpName      = "sp-$Prefix-packer"

Write-Host "`n=== Image Factory — Bootstrap Azure ===" -ForegroundColor Cyan
Write-Host "Repo alvo: $GitHubOrg/$GitHubRepo"
Write-Host "Regiao:    $Location`n"

# --- Verificar Azure CLI ---
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI nao encontrado. Instale: https://aka.ms/installazurecliwindows"
}

# --- Login / subscription ---
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "Fazendo login no Azure..." -ForegroundColor Yellow
    az login --use-device-code | Out-Null
    $account = az account show 2>$null | ConvertFrom-Json
}

if (-not $account -or -not $account.id) {
    Write-Host ""
    Write-Host "ERRO: Nenhuma subscription Azure encontrada nesta conta." -ForegroundColor Red
    Write-Host "Sua conta 'Diretorio Padrao' nao tem subscription ativa." -ForegroundColor Red
    Write-Host ""
    Write-Host "Opcoes:" -ForegroundColor Yellow
    Write-Host "  1. Criar subscription gratuita: https://azure.microsoft.com/free"
    Write-Host "  2. Portal Azure > Configuracoes > Diretorios + subscriptions > trocar diretorio"
    Write-Host "  3. az login --use-device-code  (com conta que tem subscription)"
    Write-Host ""
    exit 1
}

if ($SubscriptionId) {
    az account set --subscription $SubscriptionId | Out-Null
    $account = az account show | ConvertFrom-Json
}

$SubId    = $account.id
$TenantId = $account.tenantId

Write-Host "[OK] Subscription: $($account.name) ($SubId)" -ForegroundColor Green
Write-Host "[OK] Tenant:       $TenantId" -ForegroundColor Green

# --- Resource Groups ---
Write-Host "`n>> Criando Resource Groups..." -ForegroundColor Cyan
az group create --name $RgFactory --location $Location --tags purpose=image-factory managed_by=packer | Out-Null
az group create --name $RgBuild   --location $Location --tags purpose=packer-build managed_by=packer | Out-Null
Write-Host "[OK] $RgFactory, $RgBuild" -ForegroundColor Green

# --- Compute Gallery (SIG) ---
Write-Host "`n>> Criando Compute Gallery..." -ForegroundColor Cyan
$galleryExists = az sig show --resource-group $RgFactory --gallery-name $GalleryName 2>$null
if (-not $galleryExists) {
    az sig create --resource-group $RgFactory --gallery-name $GalleryName | Out-Null
}
Write-Host "[OK] Gallery: $GalleryName" -ForegroundColor Green

$defExists = az sig image-definition show `
    --resource-group $RgFactory --gallery-name $GalleryName `
    --gallery-image-definition $ImageDef 2>$null
if (-not $defExists) {
    az sig image-definition create `
        --resource-group $RgFactory `
        --gallery-name $GalleryName `
        --gallery-image-definition $ImageDef `
        --publisher "CorpIT" `
        --offer "GoldenUbuntu" `
        --sku "22.04" `
        --os-type Linux `
        --os-state Generalized | Out-Null
}
Write-Host "[OK] Image Definition: $ImageDef" -ForegroundColor Green

# --- App Registration + Service Principal ---
Write-Host "`n>> Criando Service Principal com OIDC..." -ForegroundColor Cyan

$appJson = az ad app create --display-name $SpName | ConvertFrom-Json
$AppId   = $appJson.appId
$AppObjId = $appJson.id

az ad sp create --id $AppId | Out-Null
Start-Sleep -Seconds 10  # propagacao Entra ID

# Federated credentials para main e develop
$federatedCredentials = @(
    @{
        name     = "github-main"
        subject  = "repo:${GitHubOrg}/${GitHubRepo}:ref:refs/heads/main"
    },
    @{
        name     = "github-develop"
        subject  = "repo:${GitHubOrg}/${GitHubRepo}:ref:refs/heads/develop"
    },
    @{
        name     = "github-pr"
        subject  = "repo:${GitHubOrg}/${GitHubRepo}:pull_request"
    }
)

foreach ($cred in $federatedCredentials) {
    $params = @{
        name      = $cred.name
        issuer    = "https://token.actions.githubusercontent.com"
        subject   = $cred.subject
        audiences = @("api://AzureADTokenExchange")
    } | ConvertTo-Json -Compress

    az ad app federated-credential create --id $AppObjId --parameters $params 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[WARN] Credential $($cred.name) pode ja existir — ignorando" -ForegroundColor Yellow
    } else {
        Write-Host "[OK] Federated credential: $($cred.name)" -ForegroundColor Green
    }
}

# --- Role Assignments ---
Write-Host "`n>> Atribuindo permissoes..." -ForegroundColor Cyan
$scopes = @(
    "/subscriptions/$SubId/resourceGroups/$RgFactory",
    "/subscriptions/$SubId/resourceGroups/$RgBuild"
)

foreach ($scope in $scopes) {
    az role assignment create `
        --assignee $AppId `
        --role "Contributor" `
        --scope $scope 2>$null | Out-Null
    Write-Host "[OK] Contributor em $scope" -ForegroundColor Green
}

# Permissao para criar VMs temporarias na subscription (build Packer)
az role assignment create `
    --assignee $AppId `
    --role "Virtual Machine Contributor" `
    --scope "/subscriptions/$SubId" 2>$null | Out-Null
Write-Host "[OK] Virtual Machine Contributor na subscription" -ForegroundColor Green

# --- Salvar output ---
$outDir = Join-Path $PSScriptRoot "output"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$output = @{
    azure_subscription_id       = $SubId
    azure_tenant_id             = $TenantId
    azure_client_id             = $AppId
    azure_build_resource_group  = $RgBuild
    azure_sig_resource_group    = $RgFactory
    azure_sig_gallery_name      = $GalleryName
    azure_sig_image_definition  = $ImageDef
    azure_location              = $Location
    github_org                  = $GitHubOrg
    github_repo                 = $GitHubRepo
}

$outputFile = Join-Path $outDir "azure-bootstrap.json"
$output | ConvertTo-Json -Depth 3 | Set-Content $outputFile -Encoding UTF8

Write-Host "`n=== Azure bootstrap concluido ===" -ForegroundColor Green
Write-Host "Arquivo gerado: $outputFile"
Write-Host "`nProximo passo:"
Write-Host "  .\scripts\setup\02-github-bootstrap.ps1 -GitHubOrg $GitHubOrg -GitHubRepo $GitHubRepo"
Write-Host ""

# Exibir valores para copiar
Write-Host "--- Valores para GitHub Secrets ---" -ForegroundColor Cyan
Write-Host "AZURE_SUBSCRIPTION_ID = $SubId"
Write-Host "AZURE_TENANT_ID       = $TenantId"
Write-Host "AZURE_CLIENT_ID       = $AppId"
Write-Host ""
Write-Host "--- Valores para GitHub Variables ---" -ForegroundColor Cyan
Write-Host "AZURE_BUILD_RESOURCE_GROUP = $RgBuild"
Write-Host "AZURE_SIG_RESOURCE_GROUP   = $RgFactory"
Write-Host "AZURE_SIG_GALLERY_NAME       = $GalleryName"
Write-Host "AZURE_SIG_IMAGE_DEFINITION   = $ImageDef"
Write-Host "AZURE_LOCATION               = $Location"
Write-Host "HCP_PACKER_BUCKET_NAME       = base-images"
