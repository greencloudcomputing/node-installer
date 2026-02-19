#!/bin/bash
set -euo pipefail

CONTAINERD_SRC="${MOUNTPOINT}/bin"
CONTAINERD_BIN_DIR="/wfs/containerd/bin"

# --- Copy containerd binaries to persistent storage ---
# Builder has already extracted thirdparty archive to ${MOUNTPOINT}/bin/
mkdir -p "${CONTAINERD_BIN_DIR}"
cp "${CONTAINERD_SRC}/containerd" "${CONTAINERD_BIN_DIR}/containerd"
cp "${CONTAINERD_SRC}/ctr" "${CONTAINERD_BIN_DIR}/ctr"
cp "${CONTAINERD_SRC}/containerd-shim-runc-v2" "${CONTAINERD_BIN_DIR}/containerd-shim-runc-v2"
cp "${CONTAINERD_SRC}/runc" "${CONTAINERD_BIN_DIR}/runc"
chmod +x "${CONTAINERD_BIN_DIR}"/*

# --- Persistent data directories ---
mkdir -p /wfs/containerd/data
mkdir -p /var/lib/greencloud

# --- sysctl config ---
echo "net.ipv4.ping_group_range = 0 2147483647" > /etc/sysctl.d/99-ping-group.conf

# --- Enable services ---
enable_system_service containerd.service
enable_system_service gcnode.service

echo "GreenCloud installation complete."
echo "Configure API key and node name in IGEL Setup: Applications > GreenCloud > Settings"
echo "Then run: greencloud-register"