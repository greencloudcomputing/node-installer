#!/bin/bash

# Run containerd installation
bash /services/greencloud/install-containerd.sh

# Enable services
enable_system_service containerd.service
enable_system_service gcnode.service

# Set executable permissions
chmod +x /services/greencloud/usr/local/bin/*
