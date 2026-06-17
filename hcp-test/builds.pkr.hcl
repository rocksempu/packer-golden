build {
  name    = "hcp-register-test"
  sources = ["source.docker.golden"]

  # Registra iteracao no HCP Packer Registry (bucket criado no 1o build)
  hcp_packer_registry {
    bucket_name = var.hcp_packer_bucket_name

    description = "Teste de registro HCP (Docker) | v${var.image_version} | sem Azure"

    bucket_labels = {
      cloud       = "docker-test"
      environment = "dev"
      purpose     = "hcp-registration"
    }

    image_labels = {
      os           = var.os_flavor
      hardened     = "true"
      managed_by   = "packer"
      registration = "hcp-test"
    }
  }

  provisioner "shell" {
    execute_command = "bash -c '{{ .Vars }} {{ .Path }}'"
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
    ]
    inline = [
      "apt-get update -y",
      "apt-get install -y ca-certificates curl",
      "echo 'BUILD_VERSION=${var.image_version}' > /etc/golden-image-version",
      "echo 'HCP_TEST=docker' >> /etc/golden-image-version",
      "echo 'OS_FLAVOR=${var.os_flavor}' >> /etc/golden-image-version",
      "cat /etc/golden-image-version",
    ]
  }
}
