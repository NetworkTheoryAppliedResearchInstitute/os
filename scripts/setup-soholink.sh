#!/bin/sh
set -e

echo "=== SoHoLINK First-Boot Setup ==="

# Create service user
if ! id -u soholink >/dev/null 2>&1; then
	adduser -D -H -s /sbin/nologin soholink
fi

# Set up directories
mkdir -p /var/lib/soholink
mkdir -p /var/log/soholink
mkdir -p /etc/soholink/policies
chown -R soholink:soholink /var/lib/soholink /var/log/soholink

# Copy default configuration if not exists
if [ ! -f /etc/soholink/config.yaml ]; then
	cp /usr/share/soholink/config.yaml.default /etc/soholink/config.yaml
	chmod 640 /etc/soholink/config.yaml
	chown root:soholink /etc/soholink/config.yaml
fi

# Generate unique RADIUS secret if default
if grep -q "testing123" /etc/soholink/config.yaml; then
	echo "WARNING: Default RADIUS secret detected!"
	echo "Generate a secure secret with: openssl rand -base64 32"
fi

# Initialize database
su -s /bin/sh soholink -c "/usr/bin/fedaaa install"

# Enable service
rc-update add soholink default

echo "=== Setup Complete ==="
echo "Edit /etc/soholink/config.yaml before starting"
echo "Start with: rc-service soholink start"
