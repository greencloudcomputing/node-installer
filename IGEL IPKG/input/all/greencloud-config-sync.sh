#!/bin/bash
# Startup script to map IGEL config parameters to files

CONFIG_DIR="/services_rw/greencloud"
mkdir -p "${CONFIG_DIR}"

# Read config from IGEL registry and write to files
# These parameters are defined in data/config/config.param

# Get API key from IGEL config
if command -v get_rmsettings >/dev/null 2>&1; then
  API_KEY=$(get_rmsettings "app" "greencloud" "api_key")
  if [[ -n "${API_KEY}" ]]; then
    echo "${API_KEY}" > "${CONFIG_DIR}/api_key"
    chmod 600 "${CONFIG_DIR}/api_key"
  fi
  
  NODE_NAME=$(get_rmsettings "app" "greencloud" "node_name")
  if [[ -n "${NODE_NAME}" ]]; then
    echo "${NODE_NAME}" > "${CONFIG_DIR}/node_name"
    chmod 644 "${CONFIG_DIR}/node_name"
  fi
  
  ENABLED=$(get_rmsettings "app" "greencloud" "enabled")
  if [[ "${ENABLED}" == "true" ]]; then
    systemctl enable gcnode.service
    systemctl start gcnode.service
  else
    systemctl disable gcnode.service
    systemctl stop gcnode.service
  fi
fi
