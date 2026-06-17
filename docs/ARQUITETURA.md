# Arquitetura — Image Factory Azure

Versão **Azure-only** do diagrama `arquitetura.jpeg` (escopo deste teste).

## Visão geral

```mermaid
flowchart TB
    subgraph trigger ["1. Código & Gatilho"]
        GH[GitHub Actions]
        PR[Pull Request]
        CRON[Schedule / Manual]
    end

    subgraph pipeline ["2. Pipeline de Build"]
        INIT[packer init]
        VAL[packer validate]
        BUILD[packer build]
        POST[post-process]
        INIT --> VAL --> BUILD --> POST
    end

    subgraph hcp ["3. HCP Packer Registry"]
        BUCKET[Bucket: base-images]
        CH_DEV[canal: dev]
        CH_HML[canal: hml]
        CH_PROD[canal: prod]
        BUCKET --> CH_DEV
        CH_DEV -.promoção.-> CH_HML
        CH_HML -.promoção.-> CH_PROD
    end

    subgraph azure ["4. Azure — Destino da Imagem"]
        SIG[Compute Gallery SIG]
        IMG[Image Definition + Version]
        SIG --> IMG
    end

    subgraph content ["Conteúdo da Golden Image"]
        OS[Ubuntu 22.04 / 24.04]
        CIS[Hardening CIS-inspired]
        PATCH[Security Patches]
        AGENTS[Azure Monitor + EDR]
        TOOLS[Ferramentas corporativas]
    end

    subgraph consume ["5. Consumo — Terraform"]
        DS[data hcp_packer_image]
        TF[Terraform / OpenTofu]
        VM[VMs / VMSS / AKS node pools]
        DS --> TF --> VM
    end

    subgraph pillars ["Pilares transversais"]
        GOV[Governança: approvals, scan CIS]
        SEC[Segredos: Vault + Azure AD OIDC]
        MON[Monitoramento: Azure Monitor]
    end

    GH --> INIT
    PR --> VAL
    BUILD --> SIG
    BUILD --> BUCKET
    POST --> CH_DEV
    CH_PROD --> DS
    IMG --> DS

    BUILD --> content
```

## Etapas numeradas (conforme diagrama)

| # | Etapa | Implementação neste repo |
|---|-------|--------------------------|
| 1 | Código & Gatilho | GitHub Actions (`push`, `PR`, `workflow_dispatch`) |
| 2 | Pipeline de Build | `packer init` → `validate` → `build` → `post-process` |
| 3 | HCP Packer Registry | Bucket `base-images`, canais `dev` / `hml` / `prod` |
| 4 | Criação de Imagem Azure | Publicação na **SIG** (Compute Gallery) |
| 5 | Consumo IaC | `data.hcp_packer_image` + Terraform (`examples/`) |
| 6-7 | Distribuição | Replicação SIG em múltiplas regiões |
| 8 | Monitoramento | Azure Monitor Agent na imagem + logs do pipeline |

## O que vai dentro da imagem

Conforme o diagrama de referência:

- **SO base**: Ubuntu 22.04 ou 24.04 LTS
- **Hardening CIS-inspired**: SSH, UFW, Fail2ban, Auditd, sysctl, PAM
- **Security patches**: unattended-upgrades
- **Agentes**: Azure Monitor Agent, EDR (placeholder configurável)
- **Ferramentas**: Azure CLI, Docker, Node Exporter, Lynis/AIDE

## Canais HCP Packer (promoção)

```
Build CI ──► dev ──(validação)──► hml ──(homologação)──► prod
```

- **dev**: builds automáticos da branch `develop`
- **hml**: promoção manual após testes
- **prod**: builds da branch `main` ou promoção aprovada

## Pilares de governança (roadmap)

| Pilar | Status | Próximo passo |
|-------|--------|---------------|
| Azure AD OIDC | Implementado no workflow | Federated credentials |
| HCP WIF | Implementado no workflow | Service Principal HCP |
| Vault para secrets | Planejado | Integrar `hcp-auth` + Vault Secrets |
| Scan CIS/OWASP | Planejado | Lynis no build + Defender for Cloud |
| Image signing | Planejado | Notation/Cosign na SIG |
| Sentinel/OPA | Planejado | Policy checks no promote |

## Diferença do diagrama original

O diagrama `arquitetura.jpeg` cobre **multicloud** (Azure + AWS + OCI).  
Este projeto de teste implementa **somente Azure**:

- Destino: Azure Compute Gallery (SIG)
- Autenticação: Azure AD OIDC
- Monitoramento: Azure Monitor
- Consumo: Terraform + `hcp_packer_image` (platform = `azure`)

## Referência visual

Diagrama original: [`arquitetura.jpeg`](../arquitetura.jpeg)
