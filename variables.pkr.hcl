# ---------------------------------------------------------------------------
# Variáveis globais — sobrescreva via .pkrvars.hcl ou PKR_VAR_* no CI/CD
# ---------------------------------------------------------------------------

variable "azure_subscription_id" {
  type        = string
  description = "ID da subscription Azure onde a imagem será publicada."
}

variable "azure_tenant_id" {
  type        = string
  description = "Tenant ID do Entra ID."
}

variable "azure_client_id" {
  type        = string
  description = "Client ID do Service Principal ou federated identity."
  default     = ""
  sensitive   = true
}

variable "azure_client_secret" {
  type        = string
  description = "Client Secret (apenas builds locais; CI usa OIDC)."
  default     = ""
  sensitive   = true
}

variable "azure_resource_group" {
  type        = string
  description = "Resource Group da VM temporária de build."
}

variable "sig_gallery_name" {
  type        = string
  description = "Nome da Azure Compute Gallery (SIG)."
  default     = "corpImageGallery"
}

variable "sig_gallery_resource_group" {
  type        = string
  description = "Resource Group onde a SIG está provisionada."
}

variable "sig_image_definition" {
  type        = string
  description = "Nome da Image Definition dentro da SIG."
  default     = "ubuntu-golden"
}

variable "sig_replication_regions" {
  type        = list(string)
  description = "Regiões de replicação da imagem na SIG."
  default     = ["brazilsouth"]
}

variable "azure_location" {
  type        = string
  description = "Região Azure (ex: brazilsouth, eastus)."
  default     = "brazilsouth"
}

variable "image_name" {
  type        = string
  description = "Nome lógico da imagem (usado em labels e metadados)."
  default     = "golden-ubuntu-22-04"
}

variable "image_version" {
  type        = string
  description = "Versão semântica da imagem (ex: 1.0.0)."
  default     = "1.0.0"
}

variable "vm_size" {
  type        = string
  description = "SKU da VM temporária usada no build."
  default     = "Standard_D2s_v3"
}

variable "os_flavor" {
  type        = string
  description = "Sistema operacional base: ubuntu-22-04 ou ubuntu-24-04."
  default     = "ubuntu-22-04"

  validation {
    condition     = contains(["ubuntu-22-04", "ubuntu-24-04"], var.os_flavor)
    error_message = "os_flavor deve ser ubuntu-22-04 ou ubuntu-24-04."
  }
}

variable "hcp_packer_bucket_name" {
  type        = string
  description = "Nome do bucket no HCP Packer Registry."
  default     = "base-images"
}

variable "hcp_packer_bucket_description" {
  type        = string
  description = "Descrição do bucket no HCP Packer."
  default     = "Golden image Ubuntu hardened para Azure"
}

variable "environment" {
  type        = string
  description = "Ambiente alvo (dev, hml, prod) — alinhado aos canais HCP Packer."
  default     = "dev"

  validation {
    condition     = contains(["dev", "hml", "prod"], var.environment)
    error_message = "environment deve ser dev, hml ou prod."
  }
}

variable "install_docker" {
  type        = string
  description = "Instalar Docker Engine na imagem."
  default     = "true"
}

variable "install_azure_cli" {
  type        = string
  description = "Instalar Azure CLI na imagem."
  default     = "true"
}

variable "install_monitoring_agent" {
  type        = string
  description = "Instalar Azure Monitor Agent (AMA)."
  default     = "true"
}

variable "install_edr_agent" {
  type        = string
  description = "Instalar agente EDR corporativo (configure URL em 03-install-apps.sh)."
  default     = "false"
}

variable "ssh_username" {
  type        = string
  description = "Usuário SSH temporário durante o build."
  default     = "packer"
}
