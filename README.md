![banner](banner.png)

# Wazuh Agent Enrollment with Terraform

## What This Does
This repository hosts the resources for provisioning EC2 instances on AWS and fully enrolls them as Wazuh agents to your
Wazuh manager. As an overview:

1. **EC2 instance creation** with IMDSv2, encrypted EBS, and SSM access
2. **Wazuh agent installation** via `user_data` on first boot (boostrapping)
3. **Auto-enrollment** using `WAZUH_REGISTRATION_PASSWORD` (authd)
  + You need to enable `authd` password enrollment and set the password file. Details are listed below on how to do that.
4. **Agent group creation** on your manager via the Wazuh REST API
5. **Optional Cloudflare Tunnel** install on each agent for manager connectivity

## Prerequisites

### On your Raspberry Pi (Wazuh Manager)
Enable password-based agent enrollment in `/var/ossec/etc/ossec.conf`:

```xml
<auth>
  <use_password>yes</use_password>
</auth>
```

Set the password:
```bash
echo "YOUR_REGISTRATION_PASSWORD" > /var/ossec/etc/authd.pass
chmod 640 /var/ossec/etc/authd.pass
chown root:wazuh /var/ossec/etc/authd.pass
systemctl restart wazuh-manager
```

Verify authd is listening:
```bash
ss -tlnp | grep 1515
```

### Cloudflare Tunnel
If you already use Cloudflare Tunnels, you may find that it's most natural to use Cloudflare Tunnels for agent management.
- For example, your Wazuh instance is not publicly accessible (e.g., it's locally hosted).

Expose port `1514` (for agent telemetry) and `55000` (API) via your tunnel config on the Pi. The `cloudflare_tunnel_token` variable in `tfvars` can install the tunnel daemon on each agent VM too.
- An example `tfvars` file is provided.

### Local Machine
- Terraform >= 1.6
- AWS credentials configured (`aws configure` or env vars)
  + You may need to install the AWS CLI on the machine you're running Terraform from.
- Python3 (used in the group creation `local-exec`)

## Usage

```bash
# 1. Clone / copy this directory
cd wazuh-agents/

# 2. Set up your variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your real values

# 3. Initialize
terraform init

# 4. Preview
terraform plan

# 5. Deploy
terraform apply

# 6. Verify on your Pi after ~2 minutes
# SSH into Pi, then:
/var/ossec/bin/agent_control -l
```

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

Then run `terraform apply` — only the new instance is created.

## Tearing Down

```bash
terraform destroy
```

Note: Destroyed EC2 instances will leave orphaned agent entries in Wazuh.
Clean them up on the Pi:
```bash
/var/ossec/bin/manage_agents  # or via Wazuh dashboard
```

## Security Notes

- `terraform.tfvars` contains secrets — **never commit it**. Add to `.gitignore`.
- Use Terraform Cloud / AWS Secrets Manager for production secret management.
- The `wazuh_registration_password` should be rotated periodically.
- IMDSv2 is enforced on all instances (`http_tokens = "required"`).
- SSM is enabled so you can access instances without opening SSH publicly.

## File Structure

```
wazuh-agents/
├── main.tf                        # EC2, SG, IAM, Wazuh API group creation
├── variables.tf                   # All input variable definitions
├── outputs.tf                     # Instance IDs, IPs, groups
├── terraform.tfvars.example       # Safe template (commit this)
├── terraform.tfvars               # Your real values (DO NOT commit)
└── templates/
    └── install_agent.sh.tpl       # user_data: agent install + enrollment
```

Thank you, and happy building!
