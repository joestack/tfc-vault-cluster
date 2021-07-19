
output "vault_server_private_ips" {
  value = aws_instance.vault_server.*.private_ip
}

output "vault_server_public_ips" {
  value = aws_instance.vault_server[*].public_ip
}

