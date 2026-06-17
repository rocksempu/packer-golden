# Setup rocksempu/packer-golden — comandos prontos

## Seus dados

| Item | Valor |
|------|-------|
| GitHub | [rocksempu/packer-golden](https://github.com/rocksempu/packer-golden) |
| Azure região | `brazilsouth` |
| Prefixo recursos | `imgfactory` |
| HCP Org | `rocksempu-org` |
| HCP Project | `1c7acb8d-7539-4a33-8d4d-5ab419faaa85` |

## Recursos que serão criados na Azure

| Recurso | Nome |
|---------|------|
| RG (SIG) | `rg-imgfactory-factory` |
| RG (build) | `rg-imgfactory-build` |
| Compute Gallery | `imgfactoryGallery` |
| Image Definition | `ubuntu-golden` |
| Service Principal | `sp-imgfactory-packer` |

---

## Passo 1 — Push do código

```powershell
cd "C:\Users\fpaix\OneDrive\Documentos\XuanZhi9\Pictures\Screenshots\other\Servicos WEB\packer"

git init
git add .
git commit -m "Image Factory Azure — golden images Packer + HCP"
git branch -M main
git remote add origin https://github.com/rocksempu/packer-golden.git
git push -u origin main

git checkout -b develop
git push -u origin develop
```

---

## Passo 2 — Bootstrap Azure (automatizado)

```powershell
az login
az account list -o table
# Se tiver mais de uma subscription:
# az account set --subscription "NOME-DA-SUA-SUBSCRIPTION"

cd scripts\setup
.\01-azure-bootstrap.ps1
```

Sem parâmetros — já vem configurado para `rocksempu/packer-golden` e `brazilsouth`.

---

## Passo 3 — Bootstrap HCP (automatizado)

```powershell
hcp auth login
```

No **Git Bash** ou **WSL**:

```bash
cd scripts/setup
bash 03-hcp-bootstrap.sh
```

---

## Passo 4 — Bootstrap GitHub (automatizado)

```powershell
gh auth login
cd scripts\setup
.\02-github-bootstrap.ps1
```

Configura automaticamente:

**Secrets:**
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_TENANT_ID`
- `AZURE_CLIENT_ID`
- `HCP_WORKLOAD_IDENTITY_PROVIDER` = `GitHub-packer-golden`
- `HCP_SERVICE_PRINCIPAL` = `packer-ci-packer-golden`

**Variables:**
- `AZURE_BUILD_RESOURCE_GROUP` = `rg-imgfactory-build`
- `AZURE_SIG_RESOURCE_GROUP` = `rg-imgfactory-factory`
- `AZURE_SIG_GALLERY_NAME` = `imgfactoryGallery`
- `AZURE_SIG_IMAGE_DEFINITION` = `ubuntu-golden`
- `AZURE_LOCATION` = `brazilsouth`
- `HCP_PACKER_BUCKET_NAME` = `base-images`

---

## Passo 5 — Primeiro build

1. Abra https://github.com/rocksempu/packer-golden/actions
2. **Image Factory — Build Azure** → **Run workflow**
3. Parâmetros:
   - Environment: `dev`
   - OS: `ubuntu-22-04`
   - Version: `1.0.0`
4. Aguarde ~15–20 min

---

## Passo 6 — Verificar

```powershell
# Imagem na SIG (Azure)
az sig image-version list `
  --resource-group rg-imgfactory-factory `
  --gallery-name imgfactoryGallery `
  --gallery-image-definition ubuntu-golden -o table

# Iteração no HCP
hcp config set project 1c7acb8d-7539-4a33-8d4d-5ab419faaa85
hcp packer buckets list-iterations base-images
```

---

## Atalho — rodar tudo de uma vez

```powershell
az login
gh auth login
cd scripts\setup
.\00-run-all.ps1
```

(O HCP ainda precisa do `bash 03-hcp-bootstrap.sh` no meio do caminho.)

---

## Promoção após testes

| Ação | Workflow | Canal |
|------|----------|-------|
| Testes OK em dev | Promote to Channel | `hml` |
| Homologação OK | Promote to Channel | `prod` |

Depois disso, Terraform consome o canal `prod` via `data.hcp_packer_image`.
