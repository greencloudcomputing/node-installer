#!/bin/bash

APP_DIR="/services/greencloud"
CONTAINERD_BIN_DIR="/wfs/containerd/bin"
SYSTEMD_DIR="/etc/systemd/system"

log() { logger -t greencloud "$*"; echo "[greencloud] $*"; }

# --- Verify critical binaries are present in persistent storage ---
for bin in containerd containerd-shim-runc-v2 runc; do
  if [[ ! -x "${CONTAINERD_BIN_DIR}/${bin}" ]]; then
    log "FATAL: ${CONTAINERD_BIN_DIR}/${bin} missing — aborting"
    exit 1
  fi
done
log "All binaries verified in ${CONTAINERD_BIN_DIR}"

# --- Kernel tuning ---
[[ -e /proc/sys/net/ipv4/ping_group_range ]] && echo "0 2147483647" > /proc/sys/net/ipv4/ping_group_range

# --- Systemd service files ---
# containerd-prestart.sh (called via ExecStartPre) handles config.toml,
# shim staging, and data dir setup — no need to duplicate that here.
ln -sf "${APP_DIR}/etc/systemd/system/containerd.service" "${SYSTEMD_DIR}/containerd.service"
ln -sf "${APP_DIR}/etc/systemd/system/gcnode.service" "${SYSTEMD_DIR}/gcnode.service"
chmod +x "${APP_DIR}/containerd-prestart.sh"
systemctl daemon-reload

# --- Config sync ---
[[ -f "${APP_DIR}/greencloud-config-sync.sh" ]] && bash "${APP_DIR}/greencloud-config-sync.sh"

# --- Start containerd (ExecStartPre will run containerd-prestart.sh first) ---
cp /services/greencloud/bin/ctr /wfs/containerd/bin/
cp /services/greencloud/bin/containerd-shim-runc-v2 /wfs/containerd/bin/
cp /services/greencloud/runc.amd64 /wfs/containerd/bin/runc
chmod +x /wfs/containerd/bin/*
ln -sf /wfs/containerd/bin/ctr /usr/bin/ctr
ln -sf /wfs/containerd/bin/containerd-shim-runc-v2 /usr/bin/containerd-shim-runc-v2
ln -sf /wfs/containerd/bin/runc /usr/bin/runc
systemctl start containerd.service
log "post_mount complete"
