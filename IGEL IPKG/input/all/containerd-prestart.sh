#!/bin/bash
# containerd-prestart.sh
# Runs as ExecStartPre in containerd.service.
# Guarantees config and shim are in place before containerd starts,
# regardless of whether post_mount.sh has completed yet.

set -euo pipefail

CONTAINERD_BIN_DIR="/wfs/containerd/bin"
CONFIG_DIR="/etc/containerd"

# --- Write config.toml ---
# /etc/containerd is non-persistent on IGEL OS so this must happen each boot.
mkdir -p "${CONFIG_DIR}"
cat > "${CONFIG_DIR}/config.toml" << 'TOML'
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
TOML

# --- Stage shim and runc into /run (tmpfs, always writable) ---
# This ensures containerd can find them via PATH=/run:... even before
# any /usr/bin symlinks are attempted.
ln -sf "${CONTAINERD_BIN_DIR}/containerd-shim-runc-v2" /run/containerd-shim-runc-v2
ln -sf "${CONTAINERD_BIN_DIR}/runc" /run/runc

# --- Ensure data dir and symlink exist ---
mkdir -p /wfs/containerd/data
if [[ -d /var/lib/containerd && ! -L /var/lib/containerd ]]; then
  rm -rf /var/lib/containerd
fi
ln -sf /wfs/containerd/data /var/lib/containerd 2>/dev/null || true

# --- Clean stale overlayfs snapshots ---
OVERLAYFS_DIR="/wfs/containerd/data/io.containerd.snapshotter.v1.overlayfs"
if [[ -d "${OVERLAYFS_DIR}" ]]; then
  rm -rf "${OVERLAYFS_DIR}"
fi

cp /services/greencloud/bin/ctr /wfs/containerd/bin/
cp /services/greencloud/bin/containerd-shim-runc-v2 /wfs/containerd/bin/
cp /services/greencloud/runc.amd64 /wfs/containerd/bin/runc
chmod +x /wfs/containerd/bin/*
ln -sf /wfs/containerd/bin/ctr /usr/bin/ctr
ln -sf /wfs/containerd/bin/containerd-shim-runc-v2 /usr/bin/containerd-shim-runc-v2
ln -sf /wfs/containerd/bin/runc /usr/bin/runc