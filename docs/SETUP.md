# Guia de Setup — Image Factory Azure

Alinhado ao diagrama `arquitetura.jpeg` (escopo: **apenas Azure**).

## Passo a passo completo para colocar em produção

### Fase 1: HCP Packer Registry

1. Acesse [HCP Portal](https://portal.cloud.hashicorp.com/) → Packer
2. Crie um projeto (ou use existente)
3. Crie o bucket:

```bash
hcp packer buckets create base-images \
  --description "Image Factory Azure — golden images"
```

4. Crie os canais de distribuição (conforme diagrama):

```bash
for ch in dev hml prod; do
  hcp packer channels create base-images "$ch"
done
```

5. Crie um Service Principal no HCP:

```bash
hcp iam service-principals create packer-ci --project <PROJECT_ID>
hcp iam service-principals keys create packer-ci --project <PROJECT_ID>
```

6. Configure Workload Identity Federation para GitHub:

```bash
hcp iam workload-identity-providers create-oidc GitHub \
  --project <PROJECT_ID> \
  --issuer-uri "https://token.actions.githubusercontent.com" \
  --allowed-audiences "https://github.com/<ORG>" \
  --conditional-access "assertion.repository=='<ORG>/<REPO>'"
```

### Fase 2: Azure — Compute Gallery (SIG)

1. Crie os Resource Groups:

```bash
az group create --name rg-image-factory --location brazilsouth
az group create --name rg-packer-build --location brazilsouth
```

2. Crie a Compute Gallery e Image Definition:

```bash
az sig create \
  --resource-group rg-image-factory \
  --gallery-name corpImageGallery

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

3. Crie o App Registration / Service Principal:

```bash
az ad sp create-for-rbac \
  --name "sp-packer-image-factory" \
  --role Contributor \
  --scopes /subscriptions/<SUB_ID>/resourceGroups/rg-image-factory
```

3. Configure Federated Credential (OIDC) para GitHub Actions:

```bash
az ad app federated-credential create \
  --id <APP_OBJECT_ID> \
  --parameters '{
    "name": "github-packer-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<ORG>/<REPO>:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

az ad app federated-credential create \
  --id <APP_OBJECT_ID> \
  --parameters '{
    "name": "github-packer-develop",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<ORG>/<REPO>:ref:refs/heads/develop",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

4. Atribua permissões na SIG:

```bash
az role assignment create \
  --assignee <SP_CLIENT_ID> \
  --role "Contributor" \
  --scope /subscriptions/<SUB_ID>/resourceGroups/rg-image-factory

az role assignment create \
  --assignee <SP_CLIENT_ID> \
  --role "Virtual Machine Contributor" \
  --scope /subscriptions/<SUB_ID>/resourceGroups/rg-packer-build
```

### Fase 3: GitHub Repository

1. Crie o repositório e faça push deste projeto
2. Configure **Secrets** (Settings → Secrets and variables → Actions):

| Secret | Valor |
|--------|-------|
| `AZURE_SUBSCRIPTION_ID` | Subscription ID |
| `AZURE_TENANT_ID` | Tenant ID |
| `AZURE_CLIENT_ID` | SP Client ID |
| `HCP_WORKLOAD_IDENTITY_PROVIDER` | Nome do provider WIF |
| `HCP_SERVICE_PRINCIPAL` | Nome do SP HCP |

3. Configure **Variables**:

| Variable | Valor |
|----------|-------|
| `AZURE_BUILD_RESOURCE_GROUP` | `rg-packer-build` |
| `AZURE_SIG_RESOURCE_GROUP` | `rg-image-factory` |
| `AZURE_SIG_GALLERY_NAME` | `corpImageGallery` |
| `AZURE_SIG_IMAGE_DEFINITION` | `ubuntu-golden` |
| `AZURE_LOCATION` | `brazilsouth` |
| `HCP_PACKER_BUCKET_NAME` | `base-images` |

4. Configure **Environments** (approvals por ambiente):
   - `dev` — sem proteção
   - `hml` — reviewers opcionais
   - `prod` — required reviewers

### Fase 4: Primeiro Build

1. Vá em Actions → "Build Golden Image" → Run workflow
2. Selecione:
   - Environment: `dev`
   - OS: `ubuntu-22-04`
   - Version: `1.0.0`
3. Aguarde o build (~15-20 min)
4. Verifique no HCP Portal → Packer → bucket → iterations

### Fase 5: Promover dev → hml → prod

1. Actions → "Promote to Channel"
2. Sequência recomendada:
   - `dev` (automático após build em develop)
   - `hml` (manual, após testes)
   - `prod` (manual, após homologação)

### Fase 6: Consumir a Imagem

```bash
# Verificar versão na SIG
az sig image-version list \
  --resource-group rg-image-factory \
  --gallery-name corpImageGallery \
  --gallery-image-definition ubuntu-golden \
  -o table
```

## Customização

### Adicionar aplicativos da empresa

Edite `scripts/03-install-apps.sh` e adicione seus provisioners:

```bash
# Exemplo: instalar agente corporativo
wget -q https://internal.company.com/agent.deb -O /tmp/agent.deb
dpkg -i /tmp/agent.deb
```

### Adicionar hardening específico

Edite `scripts/02-hardening.sh` ou adicione um provisioner Ansible:

```hcl
provisioner "ansible" {
  playbook_file = "${path.root}/ansible/hardening.yml"
}
```

### Suporte a Windows Server

Crie um novo source em `sources.pkr.hcl` com `os_type = "Windows"` e provisioners PowerShell. O fluxo HCP Packer é o mesmo.

## Troubleshooting

| Problema | Solução |
|----------|---------|
| `packer validate` falha sem credenciais | Normal — validate não precisa de auth |
| Build falha no SSH | Verifique NSG/security rules da VM temporária |
| HCP metadata não registrado | Verifique `HCP_PACKER_BUILD_FINGERPRINT` e credenciais HCP |
| OIDC falha no Azure | Verifique federated credential subject/issuer |
| Imagem muito grande | Revise `04-cleanup.sh`, remova apps desnecessários |
