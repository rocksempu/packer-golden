# Passo a passo automatizado — Image Factory Azure

Tempo estimado: **~30 min** (maior parte é o primeiro build Packer, ~15–20 min).

## O que eu preciso de você

Responda com estes dados (pode ser em texto simples):

| # | Informação | Exemplo | Obrigatório |
|---|-----------|---------|-------------|
| 1 | **URL do repo GitHub** | `https://github.com/minha-org/packer-golden` | Sim |
| 2 | **Região Azure** | `brazilsouth` (ou outra) | Sim |
| 3 | **Conta HCP (HashiCorp Cloud)** | Já tem? Sim/Não | Sim* |
| 4 | **Prefixo dos recursos** | `imgfactory` (nome curto, sem espaços) | Opcional |
| 5 | **SO da imagem** | `ubuntu-22-04` ou `ubuntu-24-04` | Opcional |

\* O pipeline usa **HCP Packer** para gerenciar releases. Sem conta HCP, o build Azure funciona, mas o registro de versões/canais não. Crie grátis em [portal.cloud.hashicorp.com](https://portal.cloud.hashicorp.com).

### Ferramentas no seu PC (instalar uma vez)

```powershell
# Azure CLI
winget install Microsoft.AzureCLI

# GitHub CLI
winget install GitHub.cli

# HCP CLI (para Fase 2)
winget install Hashicorp.HCP
```

---

## Fluxo completo (4 fases)

```
Fase 0: Push do código no GitHub
Fase 1: Bootstrap Azure        ← script automatizado (~5 min)
Fase 2: Bootstrap HCP Packer   ← script automatizado (~3 min)
Fase 3: Bootstrap GitHub       ← script automatizado (~2 min)
Fase 4: Primeiro build         ← 1 clique no GitHub Actions (~20 min)
```

---

## Fase 0 — Subir o código no GitHub

Se o repo já existe, só faça push. Se não:

```powershell
cd "C:\Users\fpaix\OneDrive\Documentos\XuanZhi9\Pictures\Screenshots\other\Servicos WEB\packer"

git init
git add .
git commit -m "Image Factory Azure — golden images com Packer + HCP"
git branch -M main
git remote add origin https://github.com/SUA-ORG/SEU-REPO.git
git push -u origin main
git checkout -b develop
git push -u origin develop
```

> O workflow dispara em `main` e `develop`. Crie as duas branches.

---

## Fase 1 — Azure (automatizado)

```powershell
# 1. Login na Azure
az login

# 2. (Opcional) Selecionar subscription correta
az account list -o table
az account set --subscription "NOME-OU-ID-DA-SUBSCRIPTION"

# 3. Rodar bootstrap
cd scripts\setup
.\01-azure-bootstrap.ps1 -GitHubOrg "SUA-ORG" -GitHubRepo "SEU-REPO"
```

**O script cria automaticamente:**
- Resource Groups (`rg-imgfactory-factory`, `rg-imgfactory-build`)
- Compute Gallery (SIG) + Image Definition
- App Registration com OIDC para GitHub (sem secrets!)
- Role assignments (Contributor + VM Contributor)

Saída salva em `scripts/setup/output/azure-bootstrap.json`.

---

## Fase 2 — HCP Packer (automatizado)

```bash
# Login HCP (abre browser)
hcp auth login

# Bootstrap
./scripts/setup/03-hcp-bootstrap.sh SUA-ORG SEU-REPO
```

**O script cria:**
- Bucket `base-images`
- Canais `dev`, `hml`, `prod`
- Service Principal + WIF para GitHub

---

## Fase 3 — GitHub Secrets/Variables (automatizado)

```powershell
# Com os valores do HCP (copie do output do passo anterior):
.\02-github-bootstrap.ps1 `
  -GitHubOrg "SUA-ORG" `
  -GitHubRepo "SEU-REPO" `
  -HcpWorkloadIdentityProvider "GitHub-SEU-REPO" `
  -HcpServicePrincipal "packer-ci-SEU-REPO"
```

**O script configura:**
- 3 secrets Azure + 2 secrets HCP
- 6 variables do projeto
- Environments `dev`, `hml`, `prod`

---

## Fase 4 — Primeiro build (1 clique)

1. Abra o repo no GitHub → **Actions**
2. Selecione **"Image Factory — Build Azure"**
3. Clique **"Run workflow"**
4. Parâmetros:
   - Environment: `dev`
   - OS: `ubuntu-22-04`
   - Version: `1.0.0`
5. Aguarde ~15–20 min

### Verificar resultado

```powershell
# Imagem na SIG
az sig image-version list `
  --resource-group rg-imgfactory-factory `
  --gallery-name imgfactoryGallery `
  --gallery-image-definition ubuntu-golden -o table

# Iteração no HCP (se tiver hcp cli)
hcp packer buckets list-iterations base-images
```

---

## Checklist rápido

```
[ ] Repo no GitHub com branches main e develop
[ ] az login feito
[ ] 01-azure-bootstrap.ps1 executado
[ ] Conta HCP criada + hcp auth login
[ ] 03-hcp-bootstrap.sh executado
[ ] 02-github-bootstrap.ps1 executado
[ ] Workflow "Image Factory — Build Azure" rodado com sucesso
[ ] Imagem visível na SIG do Azure
[ ] Iteração visível no HCP Packer (canal dev)
```

---

## Se algo falhar

| Erro | Causa provável | Solução |
|------|---------------|---------|
| `AuthorizationFailed` no Azure | Conta sem permissão de Owner/UA Admin | Peça role **Owner** ou **User Access Administrator** na subscription |
| `federated-credential` já existe | Script rodou 2x | Normal — pode ignorar |
| Build falha no HCP auth | Secrets HCP não configurados | Rode Fase 2 e 3 novamente |
| Build falha no SSH/Packer | VM temporária sem rede | Verifique quota de VMs na região |
| `packer validate` OK mas build falha | SIG não existe | Rode Fase 1 novamente |

---

## Depois do primeiro build

1. **Promover** para homologação: Actions → "Promote to Channel" → canal `hml`
2. **Testar** criando uma VM a partir da imagem
3. **Promover** para produção: canal `prod`
4. **Consumir** via Terraform (`examples/terraform-consume/main.tf`)
