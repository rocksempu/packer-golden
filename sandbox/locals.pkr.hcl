locals {
  scripts_dir = abspath("${path.root}/../scripts")

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

  managed_image_name = "${var.image_name}-${var.image_version}"
}
