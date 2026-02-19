#!/bin/bash
set -euo pipefail

CONTAINERD_SRC="${MOUNTPOINT}/bin"
CONTAINERD_BIN_DIR="/wfs/containerd/bin"
CONFIG_DIR="/etc/containerd"
SYSTEMD_DIR="/etc/systemd/system"
APP_DIR="/services/greencloud"

# --- Copy containerd binaries to persistent storage ---
mkdir -p "${CONTAINERD_BIN_DIR}"
cp "${CONTAINERD_SRC}/containerd" "${CONTAINERD_BIN_DIR}/containerd"
cp "${CONTAINERD_SRC}/ctr" "${CONTAINERD_BIN_DIR}/ctr"
cp "${CONTAINERD_SRC}/containerd-shim-runc-v2" "${CONTAINERD_BIN_DIR}/containerd-shim-runc-v2"

# --- Copy runc (downloaded as raw binary, not inside an archive) ---
cp "${MOUNTPOINT}/runc.amd64" "${CONTAINERD_BIN_DIR}/runc" 2>/dev/null || \
cp "/services/greencloud/runc.amd64" "${CONTAINERD_BIN_DIR}/runc"

chmod +x "${CONTAINERD_BIN_DIR}"/*

# --- Symlink binaries into /usr/bin ---
ln -sf "${CONTAINERD_BIN_DIR}/containerd" /usr/bin/containerd
ln -sf "${CONTAINERD_BIN_DIR}/ctr" /usr/bin/ctr
ln -sf "${CONTAINERD_BIN_DIR}/containerd-shim-runc-v2" /usr/bin/containerd-shim-runc-v2
ln -sf "${CONTAINERD_BIN_DIR}/runc" /usr/bin/runc

# --- Persistent data directories ---
mkdir -p /wfs/containerd/data
mkdir -p /var/lib/greencloud
mkdir -p /services_rw/greencloud

# --- containerd data directory symlink ---
if [[ -d /var/lib/containerd && ! -L /var/lib/containerd ]]; then
  rm -rf /var/lib/containerd
fi
ln -sf /wfs/containerd/data /var/lib/containerd

# --- Generate containerd config with native snapshotter ---
mkdir -p "${CONFIG_DIR}"
/usr/bin/containerd config default > "${CONFIG_DIR}/config.toml"
sed -i 's/snapshotter = "overlayfs"/snapshotter = "native"/g' "${CONFIG_DIR}/config.toml"

# --- sysctl config ---
echo "net.ipv4.ping_group_range = 0 2147483647" > /etc/sysctl.d/99-ping-group.conf

# --- Systemd service files ---
ln -sf "${APP_DIR}/etc/systemd/system/containerd.service" "${SYSTEMD_DIR}/containerd.service"
ln -sf "${APP_DIR}/etc/systemd/system/gcnode.service" "${SYSTEMD_DIR}/gcnode.service"
systemctl daemon-reload
enable_system_service containerd.service
enable_system_service gcnode.service

echo "GreenCloud installation complete."
echo "Configure API key and node name in IGEL Setup: Applications > GreenCloud > Settings"
echo "Then run: greencloud-register"