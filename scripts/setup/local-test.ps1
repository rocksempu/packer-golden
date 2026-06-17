# =============================================================================
# Teste local dos scripts de golden image (Docker — sem Azure)
# Uso: .\local-test.ps1
# =============================================================================

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$ScriptsDir  = Join-Path $ProjectRoot "scripts"

Write-Host ""
Write-Host "=== Teste Local — Golden Image Scripts ===" -ForegroundColor Cyan
Write-Host "Sem Azure. Roda os provisioners em Ubuntu Docker.`n"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error @"
Docker nao encontrado. Instale Docker Desktop:
  winget install Docker.DockerDesktop
Reinicie o PC e rode este script novamente.
"@
}

docker info 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker nao esta rodando. Abra o Docker Desktop e tente de novo."
}

$imageName = "golden-local-test"
$containerName = "packer-golden-test"

Write-Host ">> Construindo container Ubuntu 22.04..." -ForegroundColor Cyan
docker rm -f $containerName 2>$null | Out-Null

docker run -d --name $containerName `
    --privileged `
    -v "${ScriptsDir}:/scripts:ro" `
    ubuntu:22.04 `
    sleep 3600 | Out-Null

if ($LASTEXITCODE -ne 0) { throw "Falha ao criar container" }

function Invoke-Provisioner($script, $envVars = @()) {
    $name = Split-Path $script -Leaf
    Write-Host "`n>> $name" -ForegroundColor Yellow
    $envExport = ($envVars | ForEach-Object { "export $_;" }) -join " "
    docker exec $containerName bash -c "$envExport apt-get update -qq && bash /scripts/$name"
    if ($LASTEXITCODE -ne 0) { throw "Falha em $name" }
    Write-Host "[OK] $name" -ForegroundColor Green
}

try {
    Invoke-Provisioner "01-os-updates.sh"
    Invoke-Provisioner "02-hardening.sh" @("SSH_USERNAME=packer", "LOCAL_TEST=true")
    Invoke-Provisioner "03-install-apps.sh" @(
        "INSTALL_DOCKER=true",
        "INSTALL_AZURE_CLI=true",
        "INSTALL_MONITORING_AGENT=false",
        "INSTALL_EDR_AGENT=false"
    )
    Write-Host "`n>> Metadados da imagem" -ForegroundColor Yellow
    docker exec $containerName bash -c @"
echo 'BUILD_VERSION=1.0.0-local' | tee /etc/golden-image-version
echo 'MODE=local-docker' | tee -a /etc/golden-image-version
"@
    Invoke-Provisioner "05-validate.sh" @("LOCAL_TEST=true")

    Write-Host "`n>> Versao gravada na imagem:" -ForegroundColor Cyan
    docker exec $containerName bash -c "echo 'BUILD_VERSION=1.0.0-local' | tee /etc/golden-image-version; echo 'MODE=local-docker' | tee -a /etc/golden-image-version; cat /etc/golden-image-version"

    Write-Host "`n=== Teste local concluido com sucesso ===" -ForegroundColor Green
    Write-Host "Scripts de hardening e apps validados sem Azure."
    Write-Host "Proximo passo: obter subscription (Students/trabalho) para build real."
}
finally {
    Write-Host "`n>> Removendo container..." -ForegroundColor Cyan
    docker rm -f $containerName 2>$null | Out-Null
}
