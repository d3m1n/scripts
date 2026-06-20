#!/usr/bin/env bash

set -euo pipefail

CONF_FILE="/etc/apt/apt.conf.d/99-dotnet-blacklist"
EXPECTED_CONTENT='Unattended-Upgrade::Package-Blacklist {
  "dotnet*";
  "aspnetcore*";
};'

if [[ "$(id -u)" -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

status_changed=false

# ---------------------------------------------------------------------------
# 1. Check if file already exists with the exact expected content
# ---------------------------------------------------------------------------
if [[ -f "${CONF_FILE}" ]]; then
  CURRENT="$(cat "${CONF_FILE}")"
  if [[ "${CURRENT}" == "${EXPECTED_CONTENT}" ]]; then
    echo "No changes needed – ${CONF_FILE} already contains the correct blacklist."
    exit 0
  else
    echo "Updating ${CONF_FILE} …"
    status_changed=true
  fi
else
  echo "Creating ${CONF_FILE} …"
  status_changed=true
fi

# ---------------------------------------------------------------------------
# 2. Write the configuration (create or overwrite)
# ---------------------------------------------------------------------------
printf '%s\n' "${EXPECTED_CONTENT}" | ${SUDO} tee "${CONF_FILE}" > /dev/null

# ---------------------------------------------------------------------------
# 3. Validate the configuration syntax using apt-config
# ---------------------------------------------------------------------------
echo "Validating configuration …"
VALIDATION_OUTPUT="$(${SUDO} apt-config dump --no-pre-build 2>&1 || true)"
if echo "${VALIDATION_OUTPUT}" | grep -qi "error\|warning\|couldn't"; then
  echo "ERROR: apt-config reported problems with the new configuration:"
  echo "${VALIDATION_OUTPUT}"
  ${SUDO} rm -f "${CONF_FILE}"
  exit 1
fi

# ---------------------------------------------------------------------------
# 4. Report final status
# ---------------------------------------------------------------------------
if [[ "${status_changed}" == true ]]; then
  echo "Done – ${CONF_FILE} has been configured successfully."
fi