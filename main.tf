terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ── Data Sources ─────────────────────────────────────────────────────────────

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_vpc" "default" {
  default = true
}

# ── Security Group ────────────────────────────────────────────────────────────
# Agents initiate outbound connections to the Wazuh manager — no inbound needed
# for Wazuh traffic. Only SSH for troubleshooting (restrict to your IP).

resource "aws_security_group" "wazuh_agent" {
  name        = "${var.env_prefix}-wazuh-agent-sg"
  description = "Security group for Wazuh agent nodes"
  vpc_id      = data.aws_vpc.default.id

  # All outbound allowed — agents need to reach Wazuh manager + Cloudflare
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.env_prefix}-wazuh-agent-sg"
    Environment = var.env_prefix
    ManagedBy   = "terraform"
  }
}

# ── IAM Role for EC2 ────────────────────────────

resource "aws_iam_role" "agent_role" {
  name = "${var.env_prefix}-wazuh-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = { ManagedBy = "terraform" }
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.agent_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "agent_profile" {
  name = "${var.env_prefix}-wazuh-agent-profile"
  role = aws_iam_role.agent_role.name
}

# ── EC2 Agent Instances ───────────────────────────────────────────────────────

resource "aws_instance" "wazuh_agent" {
  for_each = var.agents

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = each.value.instance_type
  key_name               = aws_key_pair.agent_key.key_name
  vpc_security_group_ids = [aws_security_group.wazuh_agent.id]
  iam_instance_profile   = aws_iam_instance_profile.agent_profile.name

  # user_data installs the Wazuh agent and registers it to your Pi manager
  user_data = templatefile("${path.module}/templates/install_agent.sh.tpl", {
    wazuh_manager_ip      = var.wazuh_manager_ip
    wazuh_manager_port    = var.wazuh_manager_port
    wazuh_version         = var.wazuh_version
    agent_name            = each.key
    agent_group           = each.value.group
    wazuh_registration_pw = var.wazuh_registration_password
    cloudflare_tunnel_token = var.cloudflare_tunnel_token
  })

  root_block_device {
    volume_type           = "gp3"
    volume_size           = each.value.disk_gb
    delete_on_termination = true
    encrypted             = true
  }

  metadata_options {
    http_tokens = "required" # IMDSv2 enforced
  }

  tags = {
    Name        = "${var.env_prefix}-${each.key}"
    WazuhGroup  = each.value.group
    Environment = var.env_prefix
    ManagedBy   = "terraform"
  }

  lifecycle {
    ignore_changes = [ami] # Don't reprovision on AMI updates
  }
}

# ── Wazuh Agent Group Creation via API ───────────────────────────────────────
# Creates agent groups on your Wazuh manager via the REST API.
# Runs once per unique group defined in var.agents.

locals {
  unique_groups = toset([for agent in var.agents : agent.group])
}

resource "null_resource" "create_wazuh_groups" {
  for_each = local.unique_groups

  triggers = {
    group_name = each.key
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Obtain JWT token from Wazuh API
      TOKEN=$(curl -s -u "${var.wazuh_api_user}:${var.wazuh_api_password}" \
        -X POST "${var.wazuh_api_url}/security/user/authenticate" \
        -H "Content-Type: application/json" \
        -k | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['token'])")

      # Create the agent group (idempotent — 400 if exists, which we ignore)
      HTTP_CODE=$(curl -s -o /dev/null -w "%%{http_code}" \
        -X POST "${var.wazuh_api_url}/groups" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"group_id": "${each.key}"}' \
        -k)

      echo "Group '${each.key}' creation returned HTTP $HTTP_CODE"
      # 200 = created, 400 = already exists — both are acceptable
      if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "400" ]; then
        echo "ERROR: Unexpected response $HTTP_CODE creating group ${each.key}"
        exit 1
      fi
    EOT
  }
}
