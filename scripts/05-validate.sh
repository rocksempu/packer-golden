#!/usr/bin/env bash
# Validação pós-build — garante que hardening e apps estão corretos
set -euo pipefail

LOCAL_TEST="${LOCAL_TEST:-false}"

echo "==> Validando golden image..."

ERRORS=0

check() {
  local desc="$1"
  local cmd="$2"
  if eval "${cmd}"; then
    echo "  [OK] ${desc}"
  else
    echo "  [FAIL] ${desc}"
    ERRORS=$((ERRORS + 1))
  fi
}

# Serviços essenciais (systemd nao disponivel em Docker local)
if [ "${LOCAL_TEST}" != "true" ]; then
  check "UFW ativo" "ufw status | grep -q 'Status: active'"
  check "Fail2ban habilitado" "systemctl is-enabled fail2ban"
  check "Auditd habilitado" "systemctl is-enabled auditd"
fi
check "Unattended-upgrades instalado" "dpkg -l unattended-upgrades | grep -q '^ii'"

# SSH hardening
check "Root login desabilitado" "grep -q 'PermitRootLogin no' /etc/ssh/sshd_config.d/99-golden-hardening.conf"
check "Password auth desabilitado" "grep -q 'PasswordAuthentication no' /etc/ssh/sshd_config.d/99-golden-hardening.conf"

# Kernel hardening
check "ASLR habilitado" "sysctl kernel.randomize_va_space | grep -q '= 2'"

# Arquivo de versão
check "Golden image version file" "test -f /etc/golden-image-version"

# Apps opcionais
if command -v az &>/dev/null; then
  check "Azure CLI instalado" "az version"
fi

if command -v docker &>/dev/null; then
  check "Docker instalado" "docker --version"
fi

if [ -f /usr/local/bin/node_exporter ]; then
  check "Node Exporter instalado" "test -x /usr/local/bin/node_exporter"
fi

echo ""
if [ "${ERRORS}" -gt 0 ]; then
  echo "==> Validação FALHOU com ${ERRORS} erro(s)."
  exit 1
fi

echo "==> Validação concluída com sucesso."
