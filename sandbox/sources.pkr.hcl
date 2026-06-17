# Sandbox: autenticacao via "az login" — sem Service Principal
source "azure-arm" "sandbox" {
  use_azure_cli_auth = true

  # Managed Image no RG learn-* (SIG costuma ser bloqueada no sandbox)
  managed_image_name                = local.managed_image_name
  managed_image_resource_group_name = var.learn_resource_group

  location = var.azure_location
  vm_size  = var.vm_size

  os_type         = "Linux"
  image_publisher = local.selected_os.publisher
  image_offer     = local.selected_os.offer
  image_sku       = local.selected_os.sku
  image_version   = local.selected_os.version

  public_ip_sku = "Standard"
}

# Com HCP (opcional) — ative com enable_hcp_registry=true + credenciais HCP
source "azure-arm" "sandbox_hcp" {
  use_azure_cli_auth = true

  managed_image_name                = local.managed_image_name
  managed_image_resource_group_name = var.learn_resource_group

  location = var.azure_location
  vm_size  = var.vm_size

  os_type         = "Linux"
  image_publisher = local.selected_os.publisher
  image_offer     = local.selected_os.offer
  image_sku       = local.selected_os.sku
  image_version   = local.selected_os.version

  public_ip_sku = "Standard"

  hcp_packer_registry {
    bucket_name = var.hcp_packer_bucket_name
    description = "Sandbox Learn build | v${var.image_version}"
    bucket_labels = {
      cloud       = "azure"
      environment = "sandbox"
      os          = var.os_flavor
    }
    image_labels = {
      os         = var.os_flavor
      cloud      = "azure"
      sandbox    = "learn"
      managed_by = "packer"
    }
  }
}
