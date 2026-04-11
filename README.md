![banner](banner.png)

# Wazuh Cloud Agent Enrollment via Terraform

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

### Configure Wazuh Manager
Enable [password-based agent enrollment](https://documentation.wazuh.com/current/user-manual/agent/agent-enrollment/security-options/using-password-authentication.html) in `/var/ossec/etc/ossec.conf`:

```xml
<auth>
  <use_password>yes</use_password>
</auth>
```

Set the password:
```bash
echo "<CUSTOM_PASSWORD>" > /var/ossec/etc/authd.pass
chmod 640 /var/ossec/etc/authd.pass
chown root:wazuh /var/ossec/etc/authd.pass
```

Run the following command to get the Wazuh agent enrollment password:
```bash
grep "Random password" /var/ossec/logs/ossec.log
```

If you don't have Wazuh manager installed, you can run these commands:
```bash
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH \
  | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg

echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
  > /etc/apt/sources.list.d/wazuh.list

apt-get update
apt-get install wazuh-manager
systemctl enable --now wazuh-manager
```

Please note that you should not be running both the manager and the agent on the same machine. Pick one or the other.

Verify authd is listening:
```bash
ss -tlnp | grep 1515
```

### Cloudflare Tunnel
If you already use Cloudflare Tunnels, you may find that it's most natural to use Cloudflare Tunnels for agent management.
- For example, your Wazuh instance is not publicly accessible (e.g., it's locally hosted).

Expose port `1514` (for agent telemetry) and `55000` (API) via your tunnel config. The `cloudflare_tunnel_token` variable in `tfvars` can install the tunnel daemon on each agent VM too.
- An example `tfvars` file is provided.

### Local Machine
- Terraform >= 1.6
- AWS credentials configured (`aws configure` or env vars)
  + You may need to install the AWS CLI on the machine you're running Terraform from.
- Python3 (used in the group creation `local-exec`)

## Usage

```bash
# 1. Clone / copy this directory
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

## Troubeshooting
If you set up Wazuh using Docker, Docker may already be holding port 1515. The manager may already be running in Docker. Therefore, you will not need to install the `systemd` manager.
  + Instead, all manager operations will happen inside of your container via `docker exec`.

Make sure to have your AWS key already configured (`aws configure`) in the environment you're running this from.
  + It's recommended to run this in WSL or a Linux environment to not run into any issues.

Cloudflare Tunnels are HTTP-first; raw TCP for Wazuh is a nightmare (I tried it)
Docker-managed Wazuh means all operations happen via `docker exec`
`run_as`: true in Wazuh dashboard config requires RBAC setup, false is simpler for a lab

---

Please feel free to send me message or any inquiries if you are having trouble.

Thank you, and happy building!
