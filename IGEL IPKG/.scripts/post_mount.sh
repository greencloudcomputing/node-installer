#!/bin/bash

APP_DIR="/services/greencloud"
CONTAINERD_BIN_DIR="/wfs/containerd/bin"
CONFIG_DIR="/etc/containerd"
SYSTEMD_DIR="/etc/systemd/system"

log() { echo "[greencloud] $*"; journalctl -t greencloud --no-pager 2>/dev/null; logger -t greencloud "$*"; }

# --- Ensure persistent bin dir exists ---
mkdir -p "${CONTAINERD_BIN_DIR}"

# --- Copy binaries if missing ---
for bin in containerd ctr containerd-shim-runc-v2; do
  if [[ ! -f "${CONTAINERD_BIN_DIR}/${bin}" ]]; then
    cp "${APP_DIR}/bin/${bin}" "${CONTAINERD_BIN_DIR}/${bin}" && chmod +x "${CONTAINERD_BIN_DIR}/${bin}" || log "ERROR: failed to copy ${bin}"
  fi
done

if [[ ! -f "${CONTAINERD_BIN_DIR}/runc" ]]; then
  cp "${APP_DIR}/runc.amd64" "${CONTAINERD_BIN_DIR}/runc" && chmod +x "${CONTAINERD_BIN_DIR}/runc" || log "ERROR: failed to copy runc"
fi

# --- Symlink all binaries into /usr/bin ---
ln -sf "${CONTAINERD_BIN_DIR}/containerd" /usr/bin/containerd
ln -sf "${CONTAINERD_BIN_DIR}/ctr" /usr/bin/ctr
ln -sf "${CONTAINERD_BIN_DIR}/containerd-shim-runc-v2" /usr/bin/containerd-shim-runc-v2
ln -sf "${CONTAINERD_BIN_DIR}/runc" /usr/bin/runc

# --- containerd data directory ---
mkdir -p /wfs/containerd/data
mkdir -p /var/lib/greencloud
ln -sf /wfs/containerd/data /var/lib/containerd 2>/dev/null || true

# --- Clean up stale overlayfs snapshots ---
OVERLAYFS_DIR="/wfs/containerd/data/io.containerd.snapshotter.v1.overlayfs"
if [[ -d "${OVERLAYFS_DIR}" ]]; then
  log "Removing stale overlayfs snapshots"
  rm -rf "${OVERLAYFS_DIR}"
fi

# --- containerd config ---
mkdir -p "${CONFIG_DIR}"
if [[ ! -f "${CONFIG_DIR}/config.toml" ]]; then
  /usr/bin/containerd config default > "${CONFIG_DIR}/config.toml"
  sed -i 's/snapshotter = "overlayfs"/snapshotter = "native"/g' "${CONFIG_DIR}/config.toml"
fi

# --- Kernel tuning ---
[[ -e /proc/sys/net/ipv4/ping_group_range ]] && echo "0 2147483647" > /proc/sys/net/ipv4/ping_group_range

# --- Systemd service files ---
ln -sf "${APP_DIR}/etc/systemd/system/containerd.service" "${SYSTEMD_DIR}/containerd.service"
ln -sf "${APP_DIR}/etc/systemd/system/gcnode.service" "${SYSTEMD_DIR}/gcnode.service"
systemctl daemon-reload

# --- Config sync ---
[[ -f "${APP_DIR}/greencloud-config-sync.sh" ]] && bash "${APP_DIR}/greencloud-config-sync.sh"

# --- Start containerd ---
systemctl start containerd.service
log "post_mount complete"