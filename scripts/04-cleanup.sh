#!/usr/bin/env bash
# Limpeza pós-build — reduz tamanho da imagem e remove artefatos sensíveis
set -euo pipefail

echo "==> Limpando artefatos de build..."

# Limpar caches de pacotes
apt-get autoremove -y
apt-get autoclean -y
apt-get clean -y

# Remover logs e histórico
find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null || true
rm -rf /var/log/*.gz /var/log/*.1 /var/log/*.old 2>/dev/null || true
rm -f /root/.bash_history /home/*/.bash_history 2>/dev/null || true
history -c 2>/dev/null || true

# Remover chaves SSH temporárias
rm -rf /home/*/.ssh /root/.ssh 2>/dev/null || true

# Limpar cloud-init para primeira inicialização limpa
cloud-init clean --logs --seed 2>/dev/null || true
rm -rf /var/lib/cloud/instances/* 2>/dev/null || true

# Remover machine-id (será regenerado no primeiro boot)
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id

# Limpar arquivos temporários
rm -rf /tmp/* /var/tmp/* 2>/dev/null || true

# Zerar espaço livre (opcional — acelera compactação)
dd if=/dev/zero of=/EMPTY bs=1M 2>/dev/null || true
rm -f /EMPTY

echo "==> Cleanup concluído."
