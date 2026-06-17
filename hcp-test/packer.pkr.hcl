packer {
  required_version = ">= 1.14.0"

  required_plugins {
    docker = {
      source  = "github.com/hashicorp/docker"
      version = "~> 1"
    }
  }
}
