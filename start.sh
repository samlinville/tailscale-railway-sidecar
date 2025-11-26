#!/bin/sh
set -e

# Ensure state and runtime directories exist
mkdir -p /var/lib/tailscale
mkdir -p /var/run/tailscale

echo "=== Starting Tailscale Sidecar ==="
echo "Target: http://${TARGET_HOST}:${TARGET_PORT}"

# Check if we have existing state
if [ -f /var/lib/tailscale/tailscaled.state ]; then
    echo "Found existing Tailscale state, will reuse authentication"
else
    echo "No existing state found, will authenticate fresh"
fi

# Start tailscaled in userspace mode (required for Railway - no /dev/net/tun)
tailscaled \
    --state=/var/lib/tailscale/tailscaled.state \
    --socket=/var/run/tailscale/tailscaled.sock \
    --tun=userspace-networking &

# Wait for tailscaled to be ready
echo "Waiting for tailscaled to start..."
sleep 5

# Authenticate with Tailscale
echo "Authenticating to Tailscale..."
tailscale up --authkey=${TS_AUTHKEY} --hostname=${TS_HOSTNAME}

echo "=== Tailscale Status ==="
tailscale status

# Configure serve to proxy HTTPS traffic to the Laravel app
echo "Configuring Tailscale Serve..."
tailscale serve --bg --https=443 http://${TARGET_HOST}:${TARGET_PORT}

echo "=== Tailscale Serve Status ==="
tailscale serve status

echo "=== Sidecar Running ==="
echo "Access your app at: https://${TS_HOSTNAME}.${TS_TAILNET}"

# Keep container alive
tail -f /dev/null