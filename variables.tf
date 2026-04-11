variable "aws_region" {
  description = "AWS region to deploy agent instances into"
  type        = string
  default     = "us-east-1"
}

variable "env_prefix" {
  description = ""
  type        = string
  default     = "lab-dev"
}

# ── Wazuh Manager ────────────────────────────────────────

variable "wazuh_manager_ip" {
  description = "IP or hostname of your Wazuh manager (Pi). Use Cloudflare Tunnel hostname if not publicly exposed."
  type        = string
  # Example: "wazuh.yourdomain.com" or a private IP if using VPN/tunnel
}

variable "wazuh_manager_port" {
  description = "Wazuh agent enrollment port"
  type        = number
  default     = 1514
}

variable "wazuh_version" {
  description = "Wazuh agent version to install (must match your manager version)"
  type        = string
  default     = "4.9.2" # Pin this to match your Pi manager version
}

variable "wazuh_registration_password" {
  description = "Password for agent auto-enrollment (set in your manager's authd.conf)"
  type        = string
  sensitive   = true
}

# ── Cloudflare Tunnel ─────────────────────────────────────────────────────────

# token from systemctl status
variable "cloudflare_tunnel_token" {
  description = "Cloudflare Tunnel token for agent-to-manager connectivity (leave empty if manager is directly reachable)"
  type        = string
  sensitive   = true
  default     = ""
}

# ── Agent Definitions ─────────────────────────────────────────────────────────

variable "agents" {
  description = "Map of agent name → configuration. Each agent becomes one EC2 instance."
  type = map(object({
    instance_type = string
    group         = string # Wazuh agent group this agent belongs to
    disk_gb       = number
  }))

  default = {
    "web-server-01" = {
      instance_type = "t3.micro"
      group         = "web-servers"
      disk_gb       = 20
    }
    "linux-endpoint-01" = {
      instance_type = "t3.micro"
      group         = "linux-endpoints"
      disk_gb       = 20
    }
  }
}
