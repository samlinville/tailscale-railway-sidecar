FROM tailscale/tailscale:latest

# Copy config and startup script
COPY serve-config.json /config/serve-config.json
COPY start.sh /start.sh
RUN chmod +x /start.sh

# State and runtime directories will be created at runtime
# /var/lib/tailscale should be mounted as a volume for persistence

CMD ["/start.sh"]