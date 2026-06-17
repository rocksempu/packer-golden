# Configuração Image Factory — rocksempu/packer-golden
# Gerado para bootstrap automatizado

$Config = @{
    GitHubOrg   = "rocksempu"
    GitHubRepo  = "packer-golden"
    GitHubUrl   = "https://github.com/rocksempu/packer-golden"

    AzureLocation = "brazilsouth"
    AzurePrefix   = "imgfactory"

    # Resource names (derivados do prefixo)
    RgFactory   = "rg-imgfactory-factory"
    RgBuild     = "rg-imgfactory-build"
    GalleryName = "imgfactoryGallery"
    ImageDef    = "ubuntu-golden"
    SpName      = "sp-imgfactory-packer"

    # HCP
    HcpOrgId      = "36728d8a-278b-44b1-af7d-462d60a11f6a"
    HcpOrgName    = "rocksempu-org"
    HcpProjectId  = "1c7acb8d-7539-4a33-8d4d-5ab419faaa85"
    HcpBucketName = "base-images"
    HcpSpName     = "packer-ci-packer-golden"
    HcpWifName    = "GitHub-packer-golden"
}

return $Config
