build {
  name    = "golden-image-azure"
  sources = ["source.azure-arm.golden"]

  # -------------------------------------------------------------------------
  # Provisioners — ordem importa: updates → hardening → apps → cleanup
  # -------------------------------------------------------------------------

  provisioner "shell" {
    execute_command = "sudo -E bash '{{ .Path }}'"
    script          = "${path.root}/scripts/01-os-updates.sh"
  }

  provisioner "shell" {
    execute_command = "sudo -E bash '{{ .Path }}'"
    script          = "${path.root}/scripts/02-hardening.sh"
    environment_vars = [
      "SSH_USERNAME=${var.ssh_username}",
    ]
  }

  provisioner "shell" {
    execute_command = "sudo -E bash '{{ .Path }}'"
    script          = "${path.root}/scripts/03-install-apps.sh"
    environment_vars = [
      "INSTALL_DOCKER=${var.install_docker}",
      "INSTALL_AZURE_CLI=${var.install_azure_cli}",
      "INSTALL_MONITORING_AGENT=${var.install_monitoring_agent}",
      "INSTALL_EDR_AGENT=${var.install_edr_agent}",
    ]
  }

  # Metadados da build gravados na imagem (antes do cleanup)
  provisioner "shell" {
    inline = [
      "echo 'BUILD_VERSION=${var.image_version}' | sudo tee /etc/golden-image-version",
      "echo 'BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)' | sudo tee -a /etc/golden-image-version",
      "echo 'OS_FLAVOR=${var.os_flavor}' | sudo tee -a /etc/golden-image-version",
      "echo 'ENVIRONMENT=${var.environment}' | sudo tee -a /etc/golden-image-version",
      "echo 'SIG_GALLERY=${var.sig_gallery_name}' | sudo tee -a /etc/golden-image-version",
      "echo 'HARDENING=CIS-inspired' | sudo tee -a /etc/golden-image-version",
    ]
  }

  provisioner "shell" {
    execute_command = "sudo -E bash '{{ .Path }}'"
    script          = "${path.root}/scripts/05-validate.sh"
  }

  provisioner "shell" {
    execute_command = "sudo -E bash '{{ .Path }}'"
    script          = "${path.root}/scripts/04-cleanup.sh"
  }
}
