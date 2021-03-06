
data "template_file" "vault_server" {
  count = var.server_count
  template = join("\n", tolist([
    file("${path.root}/templates/10-base.sh"),
    file("${path.root}/templates/20-vault.sh")
    ]))
  vars = {
    server_count         = var.server_count
    region               = var.aws_region
    vault_join           = var.tag_value
    node_name            = format("${var.server_name}-%02d", count.index +1)
    vault_version        = var.vault_version
    vault_config_dir     = "/etc/vault.d"
    vault_env_vars       = "/etc/vault.d/vault.conf"
    vault_profile_script = "/etc/profile.d/vault.sh"
    vault_path           = "/usr/bin/vault"
    systemd_dir          = "/lib/systemd/system"
    kms_key_id           = aws_kms_key.kms_key_vault.key_id
    cert                 = tls_locally_signed_cert.vault.cert_pem
    key                  = tls_private_key.vault.private_key_pem
    ca_cert              = tls_private_key.ca.public_key_pem
    dns_domain           = var.dns_domain
  }
}

data "template_cloudinit_config" "server" {
  count = var.server_count
  gzip          = true
  base64_encode = true
  part {
    content_type = "text/x-shellscript"
    content      = element(data.template_file.vault_server.*.rendered, count.index)
  }
}

resource "aws_instance" "vault_server" {
  count                       = var.server_count
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = element(aws_subnet.vault_subnet.*.id, count.index)
  associate_public_ip_address = "true"
  vpc_security_group_ids      = [aws_security_group.primary.id]
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.vault_join.name

  tags = {
    Name     = format("${var.server_name}-%02d", count.index + 1)
    vault_join  = var.tag_value
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.root_block_device_size
    delete_on_termination = "true"
  }

  # ebs_block_device  {
  #   device_name           = "/dev/xvdd"
  #   volume_type           = "gp2"
  #   volume_size           = var.ebs_block_device_size
  #   delete_on_termination = "true"
  # }

  user_data = element(data.template_cloudinit_config.server.*.rendered, count.index)
}