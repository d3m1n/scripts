#!/usr/bin/env bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

KEYRING_DIR="/etc/apt/keyrings"
KEYRING_PATH="${KEYRING_DIR}/docker.asc"
REPO_LIST_PATH="/etc/apt/sources.list.d/docker.sources"
REMOVE_CONFLICTS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remove-conflicts)
      REMOVE_CONFLICTS=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--remove-conflicts]"
      echo "  --remove-conflicts  Remove conflicting Docker-related packages before install."
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--remove-conflicts]"
      exit 1
      ;;
  esac
done

if [[ "$(id -u)" -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

APT_ENV=(DEBIAN_FRONTEND="${DEBIAN_FRONTEND}" NEEDRESTART_MODE="${NEEDRESTART_MODE}" NEEDRESTART_SUSPEND="${NEEDRESTART_SUSPEND}")

if [[ "${REMOVE_CONFLICTS}" == "true" ]]; then
  echo "Removing conflicting packages (if installed)..."
  CONFLICTING_PKGS=(docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc)
  ${SUDO} env "${APT_ENV[@]}" apt remove -y "${CONFLICTING_PKGS[@]}" || true
else
  echo "Skipping removal of conflicting packages. Use --remove-conflicts to enable it."
fi

echo "Installing prerequisites..."
${SUDO} apt update
${SUDO} env "${APT_ENV[@]}" apt install -y ca-certificates curl

echo "Adding Docker official GPG key..."
${SUDO} install -m 0755 -d "${KEYRING_DIR}"
${SUDO} curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o "${KEYRING_PATH}"
${SUDO} chmod a+r "${KEYRING_PATH}"

echo "Configuring Docker apt repository..."
CODENAME="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"
printf "Types: deb\nURIs: https://download.docker.com/linux/ubuntu\nSuites: %s\nComponents: stable\nSigned-By: %s\n" "${CODENAME}" "${KEYRING_PATH}" | ${SUDO} tee "${REPO_LIST_PATH}" >/dev/null

echo "Installing Docker Engine and plugins..."
${SUDO} apt update
${SUDO} env "${APT_ENV[@]}" apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "Ensuring Docker service is enabled and running..."
${SUDO} systemctl enable --now docker

echo "Verifying Docker installation with hello-world..."
${SUDO} docker run --pull=always hello-world

echo "Docker installation completed."
${SUDO} docker --version
