# Ver imagem registrada no HCP Packer (sem Azure)

Para **ver uma iteracao no portal HCP** sem subscription Azure, usamos o builder **Docker** + bloco `hcp_packer_registry`.

> O registro no HCP guarda **metadados** da build (versao, labels, fingerprint).  
> A imagem Docker fica local no runner; o que importa e a iteracao no bucket.

## Antes do 1o registro

No portal HCP, em **Packer**, clique em **Create a registry** (uma vez por projeto).

## Opcao A — GitHub Actions (recomendado)

1. Confirme secrets no repo `rocksempu/packer-golden`:
   - `HCP_WORKLOAD_IDENTITY_PROVIDER` = `GitHub-packer-golden`
   - `HCP_SERVICE_PRINCIPAL` = `packer-ci-packer-golden`

2. Faca push deste repo (ou rode manual):

   **Actions → "HCP Packer — Register Test (no Azure)" → Run workflow**

3. Abra o portal:

   https://portal.cloud.hashicorp.com/org/rocksempu-org/packer

4. Va em:
   - **Packer**
   - Bucket **`base-images`**
   - Aba **Iterations**

   Voce vera uma nova iteracao com labels `registration=hcp-test`.

---

## Opcao B — Local (sua maquina)

```powershell
hcp auth login

# Criar chave do SP (uma vez) — copie client_id e secret
hcp iam service-principals keys create packer-ci-packer-golden

cd scripts\setup
.\hcp-register-local.ps1
# Informe HCP_CLIENT_ID e HCP_CLIENT_SECRET quando pedir
```

Depois abra o mesmo link do portal acima.

---

## O que NAO e este teste

| Este teste (hcp-test/) | Build Azure real |
|------------------------|------------------|
| Builder Docker | Builder azure-arm |
| Metadados no HCP | Imagem na SIG + metadados HCP |
| Sem subscription | Precisa subscription Azure |
| Platform: docker | Platform: azure |

Quando tiver subscription Azure, o workflow **Image Factory — Build Azure** registra no mesmo bucket com platform `azure`.

---

## Troubleshooting

| Erro | Solucao |
|------|---------|
| `Packer will fail... no HCP credentials` | Configure SP keys (local) ou secrets HCP (GitHub) |
| WIF falha no GitHub | Verifique `GitHub-packer-golden` e repo `rocksempu/packer-golden` |
| `no project found` | Defina `HCP_PROJECT_ID=1c7acb8d-7539-4a33-8d4d-5ab419faaa85` |
| Registry nao habilitado | Portal HCP → Packer → **Create a registry** |
| Canais dev/hml/prod vazios | Canais sao promovidos manualmente; iteracoes aparecem no bucket |
