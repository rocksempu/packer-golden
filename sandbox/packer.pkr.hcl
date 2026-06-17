packer {
  required_version = ">= 1.14.0"

  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
  }
}
