variable "learn_resource_group" {
  type        = string
  description = "RG do sandbox (copie do portal — comeca com learn-)."
}

variable "azure_location" {
  type        = string
  description = "Regiao do sandbox (ex: eastus, brazilsouth)."
  default     = "eastus"
}

variable "image_name" {
  type    = string
  default = "golden-ubuntu-sandbox"
}

variable "image_version" {
  type    = string
  default = "1.0.0"
}

variable "os_flavor" {
  type    = string
  default = "ubuntu-22-04"
}

variable "vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "install_docker" {
  type    = string
  default = "true"
}

variable "install_azure_cli" {
  type    = string
  default = "true"
}

variable "install_monitoring_agent" {
  type    = string
  default = "false"
}

variable "install_edr_agent" {
  type    = string
  default = "false"
}

variable "ssh_username" {
  type    = string
  default = "packer"
}

variable "enable_hcp_registry" {
  type        = string
  description = "Enviar metadados ao HCP Packer (requer HCP_CLIENT_ID/SECRET)."
  default     = "false"
}

variable "hcp_packer_bucket_name" {
  type    = string
  default = "base-images"
}
