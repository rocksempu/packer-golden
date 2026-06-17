# Testar sem pagar (sandbox Learn descontinuado)

> **Atualização:** O Microsoft Learn **encerrou os sandboxes** em 2025.  
> O botão "Activate sandbox" não existe mais — por isso o link deu 404.  
> Fonte: https://learn.microsoft.com/training/support/faq?pivots=sandbox

## Suas opções reais, sem pagar (ou quase)

### Opção 1 — Azure for Students (melhor se for estudante)

- https://azure.microsoft.com/free/students  
- **US$ 100** de crédito, **sem cartão** (e-mail institucional `.edu` ou verificação estudantil)  
- Depois do crédito: rode o bootstrap normal

```powershell
az login --use-device-code
cd scripts\setup
.\01-azure-bootstrap.ps1
.\02-github-bootstrap.ps1
```

---

### Opção 2 — Teste local com Docker (grátis, sem Azure)

Valida **scripts de hardening + apps** na sua máquina, sem criar nada na nuvem.

**Requisito:** Docker Desktop instalado.

```powershell
cd scripts\setup
.\local-test.ps1
```

O que testa:
- `01-os-updates.sh`
- `02-hardening.sh`
- `03-install-apps.sh`
- `05-validate.sh`

O que **não** testa: SIG, Managed Image, HCP metadata push, GitHub Actions build.

---

### Opção 3 — CI só com validate (grátis)

Push no GitHub → workflow roda `packer validate` sem custo:

```powershell
git add .
git commit -m "Image Factory"
git push origin main
```

Abra: https://github.com/rocksempu/packer-golden/actions

---

### Opção 4 — Subscription de trabalho / faculdade

Peça ao TI uma **subscription de dev/test**. É o caminho mais comum em empresas.

---

### Opção 5 — Custo mínimo na Azure (último recurso)

Se conseguir **qualquer** subscription (conta de familiar, trabalho, etc.):

| Recurso | Custo estimado |
|---------|----------------|
| VM B2s temporária (build ~20 min) | ~US$ 0,05–0,15 |
| Managed Image armazenada | ~US$ 0,01/GB/mês |

**Após o teste, delete tudo:**

```powershell
az group delete --name rg-imgfactory-factory --yes
az group delete --name rg-imgfactory-build --yes
```

---

## O que NÃO funciona mais

| Método | Status |
|--------|--------|
| Microsoft Learn Sandbox | Descontinuado (404) |
| Conta fpaixao free tier | Esgotada |
| Nova conta pessoal free | Bloqueada (não elegível) |

---

## Caminho recomendado para você agora

```
1. .\local-test.ps1          ← agora, grátis, valida scripts
2. git push                  ← valida Packer no GitHub Actions
3. Azure for Students        ← se for estudante
   OU subscription trabalho  ← se tiver acesso corporativo
4. .\01-azure-bootstrap.ps1  ← quando tiver subscription
```

---

## Pasta `sandbox/` no projeto

Ficou no repo para referência, mas **dependia do Learn Sandbox**.  
Use `local-test.ps1` no lugar até ter subscription Azure.
