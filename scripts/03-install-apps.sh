#!/usr/bin/env bash
# Instalação de aplicativos corporativos na golden image
set -euo pipefail

INSTALL_DOCKER="${INSTALL_DOCKER:-true}"
INSTALL_AZURE_CLI="${INSTALL_AZURE_CLI:-true}"
INSTALL_MONITORING_AGENT="${INSTALL_MONITORING_AGENT:-true}"
INSTALL_EDR_AGENT="${INSTALL_EDR_AGENT:-false}"

export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# Azure CLI
# ---------------------------------------------------------------------------
if [ "${INSTALL_AZURE_CLI}" = "true" ]; then
  echo "==> Instalando Azure CLI..."
  curl -sL https://aka.ms/InstallAzureCLIDeb | bash
fi

# ---------------------------------------------------------------------------
# Docker Engine
# ---------------------------------------------------------------------------
if [ "${INSTALL_DOCKER}" = "true" ]; then
  echo "==> Instalando Docker Engine..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Hardening Docker
  cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true
}
EOF

  systemctl enable docker
fi

# ---------------------------------------------------------------------------
# Azure Monitor Agent (AMA)
# ---------------------------------------------------------------------------
if [ "${INSTALL_MONITORING_AGENT}" = "true" ]; then
  echo "==> Instalando Azure Monitor Agent..."
  wget -q https://github.com/microsoft/Docker-Provider/releases/latest/download/azure-mdsd.deb -O /tmp/azure-mdsd.deb || true
  if [ -f /tmp/azure-mdsd.deb ]; then
    dpkg -i /tmp/azure-mdsd.deb || apt-get install -f -y
    rm -f /tmp/azure-mdsd.deb
  fi
fi

# ---------------------------------------------------------------------------
# Ferramentas de diagnóstico e compliance
# ---------------------------------------------------------------------------
echo "==> Instalando ferramentas de diagnóstico..."
apt-get install -y \
  lynis \
  aide \
  rkhunter

# Inicializar AIDE (baseline de integridade)
aideinit 2>/dev/null || true
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db 2>/dev/null || true

# ---------------------------------------------------------------------------
# Node Exporter (métricas Prometheus — opcional, porta interna)
# ---------------------------------------------------------------------------
NODE_EXPORTER_VERSION="1.8.2"
ARCH=$(dpkg --print-architecture)
case "${ARCH}" in
  amd64) NE_ARCH="amd64" ;;
  arm64) NE_ARCH="arm64" ;;
  *) NE_ARCH="amd64" ;;
esac

wget -q "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${NE_ARCH}.tar.gz" \
  -O /tmp/node_exporter.tar.gz
tar -xzf /tmp/node_exporter.tar.gz -C /tmp
mv "/tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-${NE_ARCH}/node_exporter" /usr/local/bin/
rm -rf /tmp/node_exporter*

cat > /etc/systemd/system/node_exporter.service <<'EOF'
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=nobody
ExecStart=/usr/local/bin/node_exporter --web.listen-address=127.0.0.1:9100
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl enable node_exporter

# ---------------------------------------------------------------------------
# Agente EDR corporativo (placeholder — configure URL interna)
# ---------------------------------------------------------------------------
if [ "${INSTALL_EDR_AGENT}" = "true" ]; then
  echo "==> Instalando agente EDR corporativo..."
  # Exemplo: substitua pela URL do repositório interno da empresa
  # wget -q https://internal.company.com/edr/agent.deb -O /tmp/edr-agent.deb
  # dpkg -i /tmp/edr-agent.deb || apt-get install -f -y
  echo "AVISO: configure a URL do EDR em scripts/03-install-apps.sh"
fi

echo "==> Instalação de aplicativos concluída."
