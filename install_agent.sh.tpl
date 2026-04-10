#!/bin/bash
# ============================================================
# Wazuh Agent Install + Auto-Enrollment Script
# Rendered by Terraform templatefile() — do not edit directly
# ============================================================
set -euo pipefail
exec > /var/log/wazuh-agent-install.log 2>&1

WAZUH_MANAGER="${wazuh_manager_ip}"
WAZUH_MANAGER_PORT="${wazuh_manager_port}"
WAZUH_VERSION="${wazuh_version}"
AGENT_NAME="${agent_name}"
AGENT_GROUP="${agent_group}"
REGISTRATION_PW="${wazuh_registration_pw}"
CF_TUNNEL_TOKEN="${cloudflare_tunnel_token}"

echo "[$(date)] Starting Wazuh agent installation..."

# ── 1. System Prerequisites ───────────────────────────────────────────────────
apt-get update -y
apt-get install -y curl apt-transport-https gnupg2 lsb-release

# ── 2. (Optional) Install Cloudflare Tunnel ──────────────────────────────────
# Only if a tunnel token is provided — needed when your Pi manager isn't
# directly reachable from the internet.
if [ -n "$CF_TUNNEL_TOKEN" ]; then
  echo "[$(date)] Installing Cloudflared tunnel..."
  curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
    | gpg --dearmor -o /usr/share/keyrings/cloudflare-main.gpg
  echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/cloudflared.list
  apt-get update -y
  apt-get install -y cloudflared
  cloudflared service install "$CF_TUNNEL_TOKEN"
  systemctl enable --now cloudflared
  echo "[$(date)] Cloudflared installed and started."
fi

# ── 3. Install Wazuh Agent ────────────────────────────────────────────────────
echo "[$(date)] Installing Wazuh agent $WAZUH_VERSION..."

curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH \
  | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg

echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
  > /etc/apt/sources.list.d/wazuh.list

apt-get update -y
WAZUH_MANAGER="$WAZUH_MANAGER" \
WAZUH_MANAGER_PORT="$WAZUH_MANAGER_PORT" \
WAZUH_AGENT_NAME="$AGENT_NAME" \
WAZUH_REGISTRATION_SERVER="$WAZUH_MANAGER" \
WAZUH_REGISTRATION_PASSWORD="$REGISTRATION_PW" \
WAZUH_AGENT_GROUP="$AGENT_GROUP" \
  apt-get install -y wazuh-agent="$${WAZUH_VERSION}-1"

# ── 4. Harden ossec.conf ──────────────────────────────────────────────────────
# The env vars above handle most config, but we ensure the manager address
# and port are set correctly in ossec.conf as a safety net.
OSSEC_CONF="/var/ossec/etc/ossec.conf"

# Set manager IP (in case env var injection didn't propagate)
sed -i "s|<address>.*</address>|<address>$WAZUH_MANAGER</address>|g" "$OSSEC_CONF"
sed -i "s|<port>.*</port>|<port>$WAZUH_MANAGER_PORT</port>|g" "$OSSEC_CONF"

echo "[$(date)] ossec.conf manager address set to $WAZUH_MANAGER:$WAZUH_MANAGER_PORT"

# ── 5. Enable and Start Agent ─────────────────────────────────────────────────
systemctl daemon-reload
systemctl enable wazuh-agent
systemctl start wazuh-agent

echo "[$(date)] Wazuh agent started. Waiting for registration..."

# ── 6. Verify Registration ────────────────────────────────────────────────────
# Give the agent up to 60s to connect and register
RETRIES=12
for i in $(seq 1 $RETRIES); do
  STATUS=$(systemctl is-active wazuh-agent || true)
  if [ "$STATUS" = "active" ]; then
    echo "[$(date)] Wazuh agent is active. Registration likely successful."
    break
  fi
  echo "[$(date)] Waiting for agent... attempt $i/$RETRIES"
  sleep 5
done

# Final status dump for CloudWatch / SSM logs
systemctl status wazuh-agent --no-pager || true
/var/ossec/bin/wazuh-control status || true

echo "[$(date)] Wazuh agent installation complete for agent: $AGENT_NAME (group: $AGENT_GROUP)"
