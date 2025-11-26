#!/bin/sh
set -e

# Ensure state and runtime directories exist
mkdir -p /var/lib/tailscale
mkdir -p /var/run/tailscale

# Substitute environment variables into serve config
sed -e "s/\${TS_HOSTNAME}/${TS_HOSTNAME}/g" \
    -e "s/\${TS_TAILNET}/${TS_TAILNET}/g" \
    -e "s/\${TARGET_HOST}/${TARGET_HOST}/g" \
    -e "s/\${TARGET_PORT}/${TARGET_PORT}/g" \
    /config/serve-config.json > /tmp/serve-config.json

echo "=== Generated serve config ==="
cat /tmp/serve-config.json
echo "==============================="

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

# Check if already authenticated
if tailscale status --json 2>/dev/null | grep -q '"BackendState":"Running"'; then
    echo "Already authenticated to Tailscale"
else
    echo "Authenticating to Tailscale..."
    tailscale up --authkey=${TS_AUTHKEY} --hostname=${TS_HOSTNAME}
fi

# Apply serve config
echo "Applying serve configuration..."
tailscale serve set-config /tmp/serve-config.json

echo "=== Tailscale Status ==="
tailscale status
echo "========================"

echo "=== Tailscale Serve Status ==="
tailscale serve status
echo "=============================="

echo "Tailscale sidecar is running. Proxying https://${TS_HOSTNAME}.${TS_TAILNET} -> http://${TARGET_HOST}:${TARGET_PORT}"

# Keep container alive
tail -f /dev/null