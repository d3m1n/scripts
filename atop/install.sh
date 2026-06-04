#!/usr/bin/env bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

ATOP_CONF="/etc/default/atop"

if [[ "$(id -u)" -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

APT_ENV=(DEBIAN_FRONTEND="${DEBIAN_FRONTEND}" NEEDRESTART_MODE="${NEEDRESTART_MODE}" NEEDRESTART_SUSPEND="${NEEDRESTART_SUSPEND}")

echo "Installing atop..."
${SUDO} apt update
${SUDO} env "${APT_ENV[@]}" apt install -y atop

echo "Configuring atop (${ATOP_CONF})..."
${SUDO} tee "${ATOP_CONF}" >/dev/null <<'EOF'
LOGOPTS="-R"
LOGINTERVAL=5
LOGGENERATIONS=2
LOGPATH=/var/log/atop
EOF

echo "Enabling and restarting atop service..."
${SUDO} systemctl enable --now atop
${SUDO} systemctl restart atop

echo "atop installation completed."
atop -V 2>&1 || atop -v 2>&1 || true