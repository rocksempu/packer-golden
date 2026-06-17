source "azure-arm" "golden" {
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret

  # Destino: Azure Compute Gallery (SIG) — padrão enterprise
  shared_image_gallery {
    gallery_name                = var.sig_gallery_name
    image_name                  = var.sig_image_definition
    image_version               = var.image_version
    gallery_resource_group_name = var.sig_gallery_resource_group
    replication_regions         = var.sig_replication_regions
  }

  location = var.azure_location
  vm_size  = var.vm_size

  os_type         = "Linux"
  image_publisher = local.selected_os.publisher
  image_offer     = local.selected_os.offer
  image_sku       = local.selected_os.sku
  image_version   = local.selected_os.version

  public_ip_sku = "Standard"

  # HCP Packer Registry — catálogo, versionamento e canais (dev → hml → prod)
  hcp_packer_registry {
    bucket_name = var.hcp_packer_bucket_name

    bucket_labels = {
      cloud       = "azure"
      environment = var.environment
      os          = var.os_flavor
    }

    description = "${var.hcp_packer_bucket_description} | v${var.image_version} | ${var.environment}"

    image_labels = local.hcp_labels
  }
}
