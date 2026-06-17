# Exemplo de consumo da golden image via Terraform + HCP Packer
# Requer: terraform provider hcp + azurerm

terraform {
  required_providers {
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.80"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

provider "hcp" {}

variable "azure_subscription_id" {
  type = string
}

variable "location" {
  type    = string
  default = "brazilsouth"
}

variable "hcp_packer_bucket" {
  type    = string
  default = "base-images"
}

variable "hcp_packer_channel" {
  type    = string
  default = "prod"
}

# Busca imagem aprovada no canal prod do HCP Packer
# O external_identifier aponta para a versão na Azure SIG
data "hcp_packer_image" "golden" {
  bucket_name = var.hcp_packer_bucket
  channel     = var.hcp_packer_channel
  platform    = "azure"
  region      = var.location
}

resource "azurerm_resource_group" "app" {
  name     = "rg-golden-app"
  location = var.location
}

resource "azurerm_linux_virtual_machine" "app" {
  name                = "vm-golden-app"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  size                = "Standard_D2s_v3"
  admin_username      = "azureuser"

  network_interface_ids = [
    azurerm_network_interface.app.id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  # Imagem vinda do HCP Packer Registry
  source_image_id = data.hcp_packer_image.golden.external_identifier

  tags = {
    golden_image_version = data.hcp_packer_image.golden.version
    hcp_iteration_id     = data.hcp_packer_image.golden.iteration_id
    image_factory        = "azure-sig"
    hcp_channel          = var.hcp_packer_channel
  }
}

resource "azurerm_virtual_network" "app" {
  name                = "vnet-golden-app"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.app.name
  virtual_network_name = azurerm_virtual_network.app.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "app" {
  name                = "nic-golden-app"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Dynamic"
  }
}

output "golden_image_id" {
  value = data.hcp_packer_image.golden.external_identifier
}

output "golden_image_version" {
  value = data.hcp_packer_image.golden.version
}

output "vm_private_ip" {
  value = azurerm_network_interface.app.private_ip_address
}
