#!/bin/bash
set -e
exec > /var/log/wazuh-agent-install.log 2>&1

echo "[$(date)] Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --authkey="${tailscale_auth_key}" --accept-routes

echo "[$(date)] Installing Wazuh agent ${wazuh_version}..."
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH \
  | gpg --no-default-keyring \
        --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import
chmod 644 /usr/share/keyrings/wazuh.gpg

echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] \
  https://packages.wazuh.com/4.x/apt/ stable main" \
  | tee /etc/apt/sources.list.d/wazuh.list

apt-get update -y

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

WAZUH_MANAGER="${wazuh_manager_ip}" \
WAZUH_REGISTRATION_SERVER="${wazuh_manager_ip}" \
WAZUH_REGISTRATION_PASSWORD="${wazuh_registration_pw}" \
WAZUH_AGENT_NAME="${agent_name}" \
WAZUH_AGENT_GROUP="${agent_group}" \
WAZUH_MANAGER_PORT="${wazuh_manager_port}" \
  apt-get install -y wazuh-agent="${wazuh_version}-1"

systemctl daemon-reload
systemctl enable wazuh-agent  
systemctl start wazuh-agent

echo "[$(date)] Done. Agent: ${agent_name}, Manager: ${wazuh_manager_ip}"