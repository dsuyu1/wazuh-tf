terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
# added remote state
terraform {
  backend "s3" {
    bucket = "your-tfstate-bucket"
    key    = "wazuh-agents/terraform.tfstate"
    region = "us-east-1"
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

  # All outbound allowed — agents need to reach Wazuh manager 
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
  vpc_security_group_ids = [aws_security_group.wazuh_agent.id]
  iam_instance_profile   = aws_iam_instance_profile.agent_profile.name

  # user_data installs the Wazuh agent and registers it to your Pi manager
user_data = templatefile("${path.module}/install_agent.sh.tpl", {
  wazuh_manager_ip      = var.wazuh_manager_ip
  wazuh_manager_port    = var.wazuh_manager_port
  wazuh_version         = var.wazuh_version
  agent_name            = each.key
  agent_group           = each.value.group
  wazuh_registration_pw = var.wazuh_registration_password
  tailscale_auth_key    = var.tailscale_auth_key
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
