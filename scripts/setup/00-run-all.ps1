# Bootstrap completo — rocksempu/packer-golden
# Executa Azure + GitHub (HCP roda separado via bash/WSL)

$ErrorActionPreference = "Stop"
$SetupDir = $PSScriptRoot
$cfg = & (Join-Path $SetupDir "config.ps1")

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Image Factory — Bootstrap rocksempu" -ForegroundColor Cyan
Write-Host " Repo:  $($cfg.GitHubUrl)" -ForegroundColor Cyan
Write-Host " Azure: $($cfg.AzureLocation)" -ForegroundColor Cyan
Write-Host " HCP:   $($cfg.HcpOrgName)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# --- Pre-checks ---
$missing = @()
if (-not (Get-Command az -ErrorAction SilentlyContinue)) { $missing += "Azure CLI (winget install Microsoft.AzureCLI)" }
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { $missing += "GitHub CLI (winget install GitHub.cli)" }

if ($missing.Count -gt 0) {
    Write-Host "Ferramentas faltando:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  - $_" }
    exit 1
}

# --- Fase 1: Azure ---
Write-Host "[FASE 1/3] Azure bootstrap..." -ForegroundColor Yellow
& (Join-Path $SetupDir "01-azure-bootstrap.ps1")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# --- Fase 2: HCP (instrucao) ---
Write-Host ""
Write-Host "[FASE 2/3] HCP Packer — execute no Git Bash ou WSL:" -ForegroundColor Yellow
Write-Host "  bash scripts/setup/03-hcp-bootstrap.sh" -ForegroundColor White
Write-Host ""
$hcpDone = Read-Host "Ja executou o bootstrap HCP? (s/N)"
if ($hcpDone -ne "s" -and $hcpDone -ne "S") {
    Write-Host "Execute o HCP bootstrap e rode este script novamente." -ForegroundColor Yellow
    exit 0
}

# --- Fase 3: GitHub ---
Write-Host ""
Write-Host "[FASE 3/3] GitHub bootstrap..." -ForegroundColor Yellow
& (Join-Path $SetupDir "02-github-bootstrap.ps1")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " Bootstrap concluido!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Proximo passo:"
Write-Host "  1. Faca push do codigo: git push origin main"
Write-Host "  2. GitHub Actions -> 'Image Factory — Build Azure' -> Run workflow"
Write-Host "     Environment: dev | OS: ubuntu-22-04 | Version: 1.0.0"
Write-Host ""
