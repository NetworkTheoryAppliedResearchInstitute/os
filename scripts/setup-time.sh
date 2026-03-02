#!/bin/sh
set -e

echo "=== Configuring time synchronization ==="

apk add --no-cache chrony

# Enable and start
rc-update add chronyd default
rc-service chronyd start

# Wait for sync
sleep 5

# Check status
chronyc tracking

echo "Time synchronization configured"
