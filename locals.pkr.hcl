locals {
  os_config = {
    "ubuntu-22-04" = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-jammy"
      sku       = "22_04-lts-gen2"
      version   = "latest"
    }
    "ubuntu-24-04" = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-noble"
      sku       = "24_04-lts-gen2"
      version   = "latest"
    }
  }

  selected_os = local.os_config[var.os_flavor]

  hcp_labels = {
    os           = var.os_flavor
    environment  = var.environment
    cloud        = "azure"
    hardened     = "true"
    cis_baseline = "true"
    managed_by   = "packer"
    image_name   = var.image_name
    sig_gallery  = var.sig_gallery_name
  }
}
