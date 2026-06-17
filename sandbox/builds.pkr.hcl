build {
  name    = "sandbox-golden"
  sources = ["source.azure-arm.sandbox"]

  provisioner "shell" {
    execute_command = "sudo -E bash '{{ .Path }}'"
    script          = "${local.scripts_dir}/01-os-updates.sh"
  }

  provisioner "shell" {
    execute_command = "sudo -E bash '{{ .Path }}'"
    script          = "${local.scripts_dir}/02-hardening.sh"
    environment_vars = [
      "SSH_USERNAME=${var.ssh_username}",
    ]
  }

  provisioner "shell" {
    execute_command = "sudo -E bash '{{ .Path }}'"
    script          = "${local.scripts_dir}/03-install-apps.sh"
    environment_vars = [
      "INSTALL_DOCKER=${var.install_docker}",
      "INSTALL_AZURE_CLI=${var.install_azure_cli}",
      "INSTALL_MONITORING_AGENT=${var.install_monitoring_agent}",
      "INSTALL_EDR_AGENT=${var.install_edr_agent}",
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'BUILD_VERSION=${var.image_version}' | sudo tee /etc/golden-image-version",
      "echo 'SANDBOX=learn' | sudo tee -a /etc/golden-image-version",
    ]
  }

  provisioner "shell" {
    execute_command = "sudo -E bash '{{ .Path }}'"
    script          = "${local.scripts_dir}/05-validate.sh"
  }

  provisioner "shell" {
    execute_command = "sudo -E bash '{{ .Path }}'"
    script          = "${local.scripts_dir}/04-cleanup.sh"
  }
}

# Com HCP: packer build -only=sandbox-golden-hcp -var-file=sandbox.pkrvars.hcl .
build {
  name    = "sandbox-golden-hcp"
  sources = ["source.azure-arm.sandbox_hcp"]

  provisioner "shell" {
    execute_command = "sudo -E bash '{{ .Path }}'"
    script          = "${local.scripts_dir}/01-os-updates.sh"
  }

  provisioner "shell" {
    execute_command = "sudo -E bash '{{ .Path }}'"
    script          = "${local.scripts_dir}/02-hardening.sh"
    environment_vars = ["SSH_USERNAME=${var.ssh_username}"]
  }

  provisioner "shell" {
    execute_command = "sudo -E bash '{{ .Path }}'"
    script          = "${local.scripts_dir}/03-install-apps.sh"
    environment_vars = [
      "INSTALL_DOCKER=${var.install_docker}",
      "INSTALL_AZURE_CLI=${var.install_azure_cli}",
      "INSTALL_MONITORING_AGENT=${var.install_monitoring_agent}",
      "INSTALL_EDR_AGENT=${var.install_edr_agent}",
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'BUILD_VERSION=${var.image_version}' | sudo tee /etc/golden-image-version",
      "echo 'SANDBOX=learn' | sudo tee -a /etc/golden-image-version",
    ]
  }

  provisioner "shell" {
    execute_command = "sudo -E bash '{{ .Path }}'"
    script          = "${local.scripts_dir}/05-validate.sh"
  }

  provisioner "shell" {
    execute_command = "sudo -E bash '{{ .Path }}'"
    script          = "${local.scripts_dir}/04-cleanup.sh"
  }
}
