output "agent_instance_ids" {
  description = "EC2 instance IDs for all provisioned Wazuh agents"
  value       = { for k, v in aws_instance.wazuh_agent : k => v.id }
}

output "agent_public_ips" {
  description = "Public IPs of agent instances (for SSH/troubleshooting)"
  value       = { for k, v in aws_instance.wazuh_agent : k => v.public_ip }
}

output "agent_private_ips" {
  description = "Private IPs of agent instances"
  value       = { for k, v in aws_instance.wazuh_agent : k => v.private_ip }
}

output "wazuh_groups_created" {
  description = "Wazuh agent groups that were created/verified"
  value       = tolist(local.unique_groups)
}

output "security_group_id" {
  description = "Security group attached to all agent instances"
  value       = aws_security_group.wazuh_agent.id
}
