variable "hcp_packer_bucket_name" {
  type        = string
  description = "Bucket no HCP Packer Registry."
  default     = "base-images"
}

variable "image_version" {
  type    = string
  default = "1.0.0"
}

variable "os_flavor" {
  type    = string
  default = "ubuntu-22-04"
}
