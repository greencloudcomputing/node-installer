#!/bin/bash
set -euo pipefail

CONTAINERD_BIN_DIR="/wfs/containerd/bin"
CONFIG_DIR="/etc/containerd"

# Create symlinks for containerd binaries
ln -sf "${CONTAINERD_BIN_DIR}/containerd" /usr/bin/containerd
ln -sf "${CONTAINERD_BIN_DIR}/ctr" /usr/bin/ctr
ln -sf "${CONTAINERD_BIN_DIR}/containerd-shim-runc-v2" /usr/bin/containerd-shim-runc-v2

# Generate containerd config
mkdir -p "${CONFIG_DIR}"
/usr/bin/containerd config default > "${CONFIG_DIR}/config.toml"

# Link containerd data to persistent partition
mkdir -p /wfs/containerd/data
if [[ -d /var/lib/containerd && ! -L /var/lib/containerd ]]; then
  rsync -aHAX /var/lib/containerd/ /wfs/containerd/data/ 2>/dev/null || true
  rm -rf /var/lib/containerd
fi
ln -sf /wfs/containerd/data /var/lib/containerd

# Configure ping_group_range for rootless containers
echo "net.ipv4.ping_group_range = 0 2147483647" > /etc/sysctl.d/99-ping-group.conf
if [[ -e /proc/sys/net/ipv4/ping_group_range ]]; then
  echo "0 2147483647" > /proc/sys/net/ipv4/ping_group_range
fi

# Run config sync to create config files from IGEL parameters
if [[ -f /services/greencloud/greencloud-config-sync.sh ]]; then
  bash /services/greencloud/greencloud-config-sync.sh
fi

# Enable services
enable_system_service containerd.service
enable_system_service gcnode.service

# Start containerd immediately
systemctl start containerd.service

echo "GreenCloud installation complete"
echo "Configure API key and node name in IGEL Setup: Applications > GreenCloud > Settings"
echo "Then run: greencloud-register"
