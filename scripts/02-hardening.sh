#!/usr/bin/env bash
# Hardening inspirado em CIS Benchmark para Ubuntu Server
set -euo pipefail

SSH_USERNAME="${SSH_USERNAME:-packer}"
LOCAL_TEST="${LOCAL_TEST:-false}"

echo "==> Aplicando hardening de segurança..."

# ---------------------------------------------------------------------------
# SSH Hardening
# ---------------------------------------------------------------------------
SSHD_CONFIG="/etc/ssh/sshd_config.d/99-golden-hardening.conf"
mkdir -p /etc/ssh/sshd_config.d

cat > "${SSHD_CONFIG}" <<'EOF'
# Golden Image SSH Hardening
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 60
AllowTcpForwarding no
AllowAgentForwarding no
Protocol 2
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
EOF

# ---------------------------------------------------------------------------
# Kernel parameters (sysctl)
# ---------------------------------------------------------------------------
cat > /etc/sysctl.d/99-golden-hardening.conf <<'EOF'
# Network security
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# IPv6
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0

# Kernel
kernel.randomize_va_space = 2
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.yama.ptrace_scope = 1
fs.suid_dumpable = 0
EOF

sysctl --system

# ---------------------------------------------------------------------------
# Firewall (UFW)
# ---------------------------------------------------------------------------
apt-get install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
if [ "${LOCAL_TEST}" = "true" ]; then
  ufw --force enable 2>/dev/null || true
else
  ufw --force enable
fi

# ---------------------------------------------------------------------------
# Fail2ban
# ---------------------------------------------------------------------------
apt-get install -y fail2ban
cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port    = ssh
filter  = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF

systemctl enable fail2ban 2>/dev/null || true

# ---------------------------------------------------------------------------
# Auditd
# ---------------------------------------------------------------------------
apt-get install -y auditd audispd-plugins
systemctl enable auditd 2>/dev/null || true

# ---------------------------------------------------------------------------
# AppArmor
# ---------------------------------------------------------------------------
apt-get install -y apparmor apparmor-utils
systemctl enable apparmor 2>/dev/null || true

# ---------------------------------------------------------------------------
# Desabilitar serviços desnecessários
# ---------------------------------------------------------------------------
for svc in avahi-daemon cups bluetooth; do
  systemctl disable "${svc}" 2>/dev/null || true
  systemctl stop "${svc}" 2>/dev/null || true
done

# ---------------------------------------------------------------------------
# Permissões de arquivos críticos
# ---------------------------------------------------------------------------
chmod 600 /etc/ssh/sshd_config 2>/dev/null || true
chmod 700 /root
chmod 644 /etc/passwd /etc/group
chmod 600 /etc/shadow /etc/gshadow

# ---------------------------------------------------------------------------
# Política de senha (PAM)
# ---------------------------------------------------------------------------
apt-get install -y libpam-pwquality
if ! grep -q "pam_pwquality.so" /etc/pam.d/common-password; then
  sed -i '/pam_unix.so/a password requisite pam_pwquality.so retry=3 minlen=14 dcredit=-1 ucredit=-1 lcredit=-1 ocredit=-1' /etc/pam.d/common-password
fi

# ---------------------------------------------------------------------------
# Remover usuário temporário do Packer
# ---------------------------------------------------------------------------
if id "${SSH_USERNAME}" &>/dev/null; then
  userdel -r "${SSH_USERNAME}" 2>/dev/null || true
fi

# Remover chaves SSH do root
rm -rf /root/.ssh

echo "==> Hardening concluído."
