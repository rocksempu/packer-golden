# Builder Docker — nao precisa de Azure para registrar metadados no HCP Packer
source "docker" "golden" {
  image  = "ubuntu:22.04"
  commit = true
}
