![banner](banner.png)

# Wazuh Cloud Agent Enrollment via Terraform

Terraform module for provisioning AWS EC2 instances and automatically enrolling them as Wazuh agents into your Wazuh manager — including agent installation, auto-enrollment via authd, and zero-trust networking via Tailscale.

Built and maintained by [VISI (Vaquero Information Security Initiative)](https://vaqueroisi.org) at UTRGV.

---

## What This Does

1. **EC2 instance creation** with IMDSv2, encrypted EBS, and SSM access
2. **Tailscale installation** on each agent for zero-trust connectivity to your manager
3. **Wazuh agent installation** via `user_data` on first boot (bootstrapping)
4. **Auto-enrollment** using `WAZUH_REGISTRATION_PASSWORD` (authd)

> **Why Tailscale?** Cloudflare Tunnels are HTTP-first. Wazuh agents communicate over raw TCP on ports 1514 and 1515, which Cloudflare cannot proxy transparently without `cloudflared` running on every agent — and even then it's unreliable. Tailscale creates a WireGuard mesh where your manager is reachable at a stable `100.x.x.x` IP from any agent, anywhere. It just works.

---

## Prerequisites

### 1. Wazuh Manager

This module assumes you already have a Wazuh manager running. If your manager runs in Docker (common for self-hosted setups), all manager operations happen inside the container:

```bash
docker exec -it <wazuh-manager-container> /bin/bash
```

**Enable password-based agent enrollment** in `/var/ossec/etc/ossec.conf`:

```xml
<auth>
  <use_password>yes</use_password>
</auth>
```

**Set the registration password:**

```bash
echo "<YOUR_REGISTRATION_PASSWORD>" > /var/ossec/etc/authd.pass
chmod 640 /var/ossec/etc/authd.pass
chown root:wazuh /var/ossec/etc/authd.pass
```

**Restart the manager:**

```bash
# Systemd
systemctl restart wazuh-manager

# Docker
docker restart <wazuh-manager-container>
```

**Verify authd is listening:**

```bash
ss -tlnp | grep 1515
```

> **Docker note:** If you installed Wazuh via the official Docker single-node deployment, Docker is likely already holding port 1515. Do not install the systemd `wazuh-manager` package alongside it — pick one or the other. If you're running Docker, you don't need the systemd manager.

---

### 2. Tailscale

Install Tailscale on your Wazuh manager machine:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
```

Get your manager's Tailscale IP — this goes into `terraform.tfvars` as `wazuh_manager_ip`:

```bash
tailscale ip -4
# Example output: 100.98.68.3
```

Generate a **reusable ephemeral auth key** for EC2 agents at [login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys). This goes into `terraform.tfvars` as `tailscale_auth_key`.

> Ephemeral keys mean agents automatically disappear from your Tailscale network when they're destroyed — no manual cleanup needed.

---

### 3. Local Machine

- Terraform >= 1.6
- AWS credentials configured (`aws configure` or environment variables)
- It's recommended to run this from WSL or a Linux environment to avoid issues with line endings in shell scripts

---

## Usage

```bash
# 1. Clone the repo
git clone https://github.com/dsuyu1/wazuh-tf.git
cd wazuh-tf

# 2. Set up your variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your real values

# 3. Initialize
terraform init

# 4. Preview
terraform plan

# 5. Deploy
terraform apply

# 6. Verify enrollment (~2 minutes after apply)
docker exec -it <wazuh-manager-container> /var/ossec/bin/agent_control -l
```

---

## Adding More Agents

Edit the `agents` map in `terraform.tfvars`:

```hcl
agents = {
  "new-agent-name" = {
    instance_type = "t3.micro"
    group         = "existing-or-new-group"
    disk_gb       = 20
  }
}
```

Then run `terraform apply` — only the new instance is created. Existing agents are untouched.

---

## Tearing Down

```bash
terraform destroy
```

Destroyed EC2 instances will leave orphaned agent entries in Wazuh. Clean them up via the Wazuh dashboard or:

```bash
docker exec -it <wazuh-manager-container> /var/ossec/bin/manage_agents
```

Since agents use ephemeral Tailscale keys, they'll automatically disappear from your Tailscale network on destroy.

---

## Security Notes

- `terraform.tfvars` contains secrets — **never commit it**. It's in `.gitignore` for a reason.
- Use Terraform Cloud or AWS Secrets Manager for production secret management.
- Rotate `wazuh_registration_password` periodically.
- IMDSv2 is enforced on all instances (`http_tokens = "required"`).
- No inbound ports are open on agent instances — access is via SSM only.

---

## File Structure

```
wazuh-tf/
├── main.tf                        # EC2, SG, IAM resources
├── variables.tf                   # All input variable definitions
├── outputs.tf                     # Instance IDs, IPs
├── terraform.tfvars.example       # Safe template (commit this)
├── terraform.tfvars               # Your real values (DO NOT commit)
├── CONTRIBUTING.md                # How to contribute
├── LICENSE                        # Apache 2.0
└── templates/
    └── install_agent.sh.tpl       # user_data: Tailscale + Wazuh install
```

---

## Troubleshooting

**Agents not showing in Wazuh dashboard but active in `agent_control -l`**
This is usually the `run_as: true` setting in your Wazuh dashboard config. Set it to `false`:
```bash
# Find your dashboard config and update
sed -i 's/run_as: true/run_as: false/' /path/to/wazuh.yml
docker restart <wazuh-dashboard-container>
```

**`terraform apply` hangs or fails with bash errors on Windows**
Run from WSL, not PowerShell. The install scripts use bash syntax that PowerShell cannot handle.

**Agents enrolled but showing wrong name (e.g. `ip-172-31-x-x`)**
Make sure `WAZUH_AGENT_NAME` in the template is set to `${agent_name}` from your tfvars, not the EC2 hostname.

**`grep "Random password"` returns nothing**
On Docker deployments, the random password is logged once at first install and rotates out quickly. Retrieve your API credentials from your `docker-compose.yml` or `.env` file instead.

**Port 1515 already in use**
If you're running Wazuh in Docker, Docker is already holding 1515. Don't install the systemd `wazuh-manager` package — it will conflict. All manager operations should happen inside the container via `docker exec`.

---

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->

---

Feel free to open an issue or start a discussion if you're running into trouble. Happy building!

— [VISI](https://vaqueroisi.org) | University of Texas Rio Grande Valley
