# Sandbox Microsoft Learn — DESCONTINUADO

> **Este metodo nao funciona mais.** Microsoft encerrou os sandboxes em 2025.  
> Use: [`TESTE-SEM-AZURE.md`](TESTE-SEM-AZURE.md)

## Alternativa imediata (gratis)

```powershell
cd scripts\setup
.\local-test.ps1
```

Valida os scripts de golden image em Docker, sem Azure.

## Quando tiver subscription

```powershell
.\01-azure-bootstrap.ps1
.\02-github-bootstrap.ps1
```
