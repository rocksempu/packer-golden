#!/usr/bin/env bash
# Atualizações de SO e pacotes de segurança base
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "==> Atualizando repositórios e pacotes de segurança..."
apt-get update -y
apt-get upgrade -y
apt-get dist-upgrade -y

echo "==> Instalando pacotes base..."
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  software-properties-common \
  unzip \
  jq \
  htop \
  vim \
  net-tools \
  dnsutils \
  wget \
  git \
  rsync \
  openssh-server \
  cloud-init \
  cloud-guest-utils

echo "==> Configurando unattended-upgrades..."
apt-get install -y unattended-upgrades apt-listchanges
dpkg-reconfigure -f noninteractive unattended-upgrades

cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

echo "==> OS updates concluído."
