#!/bin/bash
set -euo pipefail

APP_DIR="/services/greencloud"
CONTAINERD_BIN_DIR="/wfs/containerd/bin"
CONFIG_DIR="/etc/containerd"
SYSTEMD_DIR="/etc/systemd/system"

# --- Containerd binaries ---
# Symlink from persistent storage into /usr/bin
if [[ -f "${CONTAINERD_BIN_DIR}/containerd" ]]; then
  ln -sf "${CONTAINERD_BIN_DIR}/containerd" /usr/bin/containerd
  ln -sf "${CONTAINERD_BIN_DIR}/ctr" /usr/bin/ctr
  ln -sf "${CONTAINERD_BIN_DIR}/containerd-shim-runc-v2" /usr/bin/containerd-shim-runc-v2
else
  echo "[greencloud] ERROR: containerd binaries not found at ${CONTAINERD_BIN_DIR}"
  echo "[greencloud] Re-run install by unassigning and reassigning the app in UMS."
  exit 1
fi

# --- containerd data directory symlink ---
mkdir -p /wfs/containerd/data
if [[ -d /var/lib/containerd && ! -L /var/lib/containerd ]]; then
  rm -rf /var/lib/containerd
fi
ln -sf /wfs/containerd/data /var/lib/containerd

# --- containerd config ---
mkdir -p "${CONFIG_DIR}"
if [[ ! -f "${CONFIG_DIR}/config.toml" ]]; then
  /usr/bin/containerd config default > "${CONFIG_DIR}/config.toml"
fi

# --- Kernel tuning ---
if [[ -e /proc/sys/net/ipv4/ping_group_range ]]; then
  echo "0 2147483647" > /proc/sys/net/ipv4/ping_group_range
fi

# --- Systemd service files ---
ln -sf "${APP_DIR}/etc/systemd/system/containerd.service" "${SYSTEMD_DIR}/containerd.service"
ln -sf "${APP_DIR}/etc/systemd/system/gcnode.service" "${SYSTEMD_DIR}/gcnode.service"
systemctl daemon-reload

# --- Config sync ---
if [[ -f "${APP_DIR}/greencloud-config-sync.sh" ]]; then
  bash "${APP_DIR}/greencloud-config-sync.sh"
fi

# --- Start containerd ---
systemctl start containerd.service
echo "[greencloud] post_mount complete"