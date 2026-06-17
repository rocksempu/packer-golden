# Image Factory Azure — Golden Images com Packer + HCP Packer

Pipeline de **golden images** para Azure, alinhado ao diagrama de arquitetura corporativa (`arquitetura.jpeg`).  
**Escopo deste teste: apenas Azure** (SIG + HCP Packer + GitHub Actions + Terraform).

## Arquitetura (Azure-only)

```
GitHub (gatilho)
    │
    ├── PR  → packer validate
    │
    └── push / manual
            │
            ├── packer init
            ├── packer validate
            ├── packer build ──► Azure SIG (Compute Gallery)
            │                 └──► HCP Packer Registry (bucket: base-images)
            │
            └── post-process
                    ├── verificar imagem na SIG
                    └── promover canal HCP (dev / hml / prod)
                            │
                            └── Terraform consome canal prod → VMs
```

Documentação completa: [`docs/ARQUITETURA.md`](docs/ARQUITETURA.md)

## Conteúdo da golden image

| Camada | O que inclui |
|--------|--------------|
| SO | Ubuntu 22.04 / 24.04 LTS |
| Hardening | CIS-inspired (SSH, UFW, Fail2ban, Auditd, sysctl, PAM) |
| Patches | unattended-upgrades automático |
| Agentes | Azure Monitor Agent, EDR (configurável) |
| Ferramentas | Azure CLI, Docker, Node Exporter, Lynis/AIDE |

## Pré-requisitos Azure

```bash
# 1. Resource Group para build e SIG
az group create --name rg-image-factory --location brazilsouth

# 2. Criar Compute Gallery (SIG)
az sig create \
  --resource-group rg-image-factory \
  --gallery-name corpImageGallery

# 3. Criar Image Definition
az sig image-definition create \
  --resource-group rg-image-factory \
  --gallery-name corpImageGallery \
  --gallery-image-definition ubuntu-golden \
  --publisher "CorpIT" \
  --offer "GoldenUbuntu" \
  --sku "22.04" \
  --os-type Linux \
  --os-state Generalized
```

## HCP Packer

```bash
hcp packer buckets create base-images \
  --description "Image Factory Azure — golden images"

for ch in dev hml prod; do
  hcp packer channels create base-images "$ch"
done
```

## GitHub — Secrets e Variables

**Secrets:**

| Secret | Descrição |
|--------|-----------|
| `AZURE_SUBSCRIPTION_ID` | Subscription ID |
| `AZURE_TENANT_ID` | Tenant ID |
| `AZURE_CLIENT_ID` | SP com OIDC |
| `HCP_WORKLOAD_IDENTITY_PROVIDER` | WIF provider HCP |
| `HCP_SERVICE_PRINCIPAL` | SP HCP |

**Variables:**

| Variable | Exemplo |
|----------|---------|
| `AZURE_BUILD_RESOURCE_GROUP` | `rg-packer-build` |
| `AZURE_SIG_RESOURCE_GROUP` | `rg-image-factory` |
| `AZURE_SIG_GALLERY_NAME` | `corpImageGallery` |
| `AZURE_SIG_IMAGE_DEFINITION` | `ubuntu-golden` |
| `AZURE_LOCATION` | `brazilsouth` |
| `HCP_PACKER_BUCKET_NAME` | `base-images` |

## Build local

```bash
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
packer init .
packer validate -var-file=variables.pkrvars.hcl .
packer build -var-file=variables.pkrvars.hcl .
```

## Consumo via Terraform

```hcl
data "hcp_packer_image" "golden" {
  bucket_name = "base-images"
  channel     = "prod"
  platform    = "azure"
  region      = "brazilsouth"
}

resource "azurerm_linux_virtual_machine" "app" {
  source_image_id = data.hcp_packer_image.golden.external_identifier
  # ...
}
```

Exemplo completo: [`examples/terraform-consume/main.tf`](examples/terraform-consume/main.tf)

## Estrutura

```
.
├── arquitetura.jpeg              # Diagrama de referência (multicloud)
├── .github/workflows/
│   ├── packer-build.yml          # init → validate → build → post-process
│   └── promote-channel.yml       # dev → hml → prod
├── scripts/                      # Provisioners da imagem
├── docs/
│   ├── ARQUITETURA.md            # Arquitetura Azure-only
│   └── SETUP.md                  # Guia passo a passo
├── examples/terraform-consume/   # Consumo SIG via HCP
└── *.pkr.hcl                     # Config Packer modular
```

## Fluxo de promoção

```
CI build (develop) ──► canal dev
         │
         ▼ (testes OK)
    promote manual ──► canal hml
         │
         ▼ (homologação OK)
    promote manual ──► canal prod  ◄── Terraform consome daqui
```

Setup detalhado: [`docs/SETUP.md`](docs/SETUP.md)
