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

# --- Copy runc ---
cp "${MOUNTPOINT}/runc.amd64" "${CONTAINERD_BIN_DIR}/runc" 2>/dev/null || \
cp "/services/greencloud/runc.amd64" "${CONTAINERD_BIN_DIR}/runc"

chmod +x "${CONTAINERD_BIN_DIR}"/*

# NOTE: We do NOT symlink into /usr/bin — it is on the read-only IGEL OS
# partition and symlinks placed there do not survive reboots.
# containerd.service sets Environment="PATH=..." to include /wfs/containerd/bin.

# --- Wipe stale containerd data to avoid snapshotter conflicts ---
# Any pre-existing data may reference overlayfs snapshots; start clean.
rm -rf /wfs/containerd/data
mkdir -p /wfs/containerd/data

# --- Persistent data directories ---
mkdir -p /var/lib/greencloud
mkdir -p /services_rw/greencloud

# --- containerd data directory symlink ---
if [[ -d /var/lib/containerd && ! -L /var/lib/containerd ]]; then
  rm -rf /var/lib/containerd
fi
ln -sf /wfs/containerd/data /var/lib/containerd

# --- Write containerd config explicitly (do not rely on sed of generated output) ---
# Using native snapshotter avoids the need for overlayfs kernel support on IGEL OS.
mkdir -p "${CONFIG_DIR}"
cat > "${CONFIG_DIR}/config.toml" << 'EOF'
version = 2

[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".containerd]
      snapshotter = "native"
      default_runtime_name = "runc"

      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"

          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            BinaryName = "/wfs/containerd/bin/runc"

  [plugins."io.containerd.snapshotter.v1.native"]
    root_path = "/wfs/containerd/data/io.containerd.snapshotter.v1.native"
EOF

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
