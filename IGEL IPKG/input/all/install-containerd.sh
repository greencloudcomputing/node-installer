#!/bin/bash
set -euo pipefail

INSTALL_BASE="/wfs/containerd"
BIN_DIR="${INSTALL_BASE}/bin"
CONFIG_DIR="/etc/containerd"

# Extract containerd
mkdir -p "${BIN_DIR}"
tar -xzf /services/greencloud/tmp/containerd.tgz -C /tmp
cp -r /tmp/bin/* "${BIN_DIR}/"

# Create symlinks
ln -sf "${BIN_DIR}/containerd" /usr/bin/containerd
ln -sf "${BIN_DIR}/ctr" /usr/bin/ctr
ln -sf "${BIN_DIR}"/containerd-shim* /usr/bin/

# Generate config
mkdir -p "${CONFIG_DIR}"
/usr/bin/containerd config default > "${CONFIG_DIR}/config.toml"

# Link containerd data to persistent partition
mkdir -p /wfs/containerd
if [[ -d /var/lib/containerd && ! -L /var/lib/containerd ]]; then
  rsync -aHAX /var/lib/containerd/ /wfs/containerd/ 2>/dev/null || true
  rm -rf /var/lib/containerd
fi
ln -sf /wfs/containerd /var/lib/containerd

# Configure ping_group_range
echo "net.ipv4.ping_group_range = 0 2147483647" > /etc/sysctl.d/99-ping-group.conf
if [[ -e /proc/sys/net/ipv4/ping_group_range ]]; then
  echo "0 2147483647" > /proc/sys/net/ipv4/ping_group_range
fi
