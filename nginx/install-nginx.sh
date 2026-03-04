#!/usr/bin/env bash

set -euo pipefail

EXPECTED_FPR="573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62"
KEYRING_PATH="/usr/share/keyrings/nginx-archive-keyring.gpg"
REPO_LIST_PATH="/etc/apt/sources.list.d/nginx.list"
PINNING_PATH="/etc/apt/preferences.d/99nginx"
NGINX_CONF="/etc/nginx/nginx.conf"

CHANNEL="${1:-stable}"
if [[ "${CHANNEL}" != "stable" && "${CHANNEL}" != "mainline" ]]; then
  echo "Usage: $0 [stable|mainline]"
  exit 1
fi

if [[ "$(id -u)" -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

echo "Installing prerequisites..."
${SUDO} apt update
${SUDO} apt install -y curl gnupg2 ca-certificates lsb-release ubuntu-keyring

echo "Importing nginx signing key..."
curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor | ${SUDO} tee "${KEYRING_PATH}" >/dev/null

echo "Verifying nginx signing key fingerprint..."
KEY_INFO="$(gpg --dry-run --quiet --no-keyring --import --import-options import-show "${KEYRING_PATH}" 2>&1 || true)"
if [[ "${KEY_INFO}" != *"${EXPECTED_FPR}"* ]]; then
  echo "ERROR: nginx signing key fingerprint mismatch."
  echo "Expected: ${EXPECTED_FPR}"
  echo "Got:"
  echo "${KEY_INFO}"
  exit 1
fi

CODENAME="$(lsb_release -cs)"
if [[ "${CHANNEL}" == "mainline" ]]; then
  REPO_URL="https://nginx.org/packages/mainline/ubuntu"
else
  REPO_URL="https://nginx.org/packages/ubuntu"
fi

echo "Configuring nginx ${CHANNEL} repository for Ubuntu ${CODENAME}..."
echo "deb [signed-by=${KEYRING_PATH}] ${REPO_URL} ${CODENAME} nginx" | ${SUDO} tee "${REPO_LIST_PATH}" >/dev/null

echo "Configuring apt pinning..."
printf "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" | ${SUDO} tee "${PINNING_PATH}" >/dev/null

echo "Installing nginx..."
${SUDO} apt update
${SUDO} apt install -y nginx

echo "Configuring nginx worker user to www-data..."
if ! id -u www-data >/dev/null 2>&1; then
  echo "Creating www-data user..."
  ${SUDO} useradd --system --home-dir /var/www --create-home --shell /usr/sbin/nologin www-data
fi

echo "Ensuring /var/www exists with required permissions..."
if [[ ! -d /var/www ]]; then
  ${SUDO} mkdir -p /var/www
fi
${SUDO} chown www-data:www-data /var/www
${SUDO} chmod 0755 /var/www

if ${SUDO} grep -qE '^user[[:space:]]+' "${NGINX_CONF}"; then
  ${SUDO} sed -i -E 's/^user[[:space:]]+[^;]+;/user www-data;/' "${NGINX_CONF}"
else
  printf 'user www-data;\n' | ${SUDO} cat - "${NGINX_CONF}" | ${SUDO} tee "${NGINX_CONF}" >/dev/null
fi

echo "Validating nginx configuration..."
${SUDO} nginx -t

echo "Restarting nginx service..."
${SUDO} systemctl enable --now nginx
${SUDO} systemctl restart nginx

echo "nginx installation completed."
nginx -v
