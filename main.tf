provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {}

locals {
  mod_az = length(data.aws_availability_zones.available.names)
  #mod_az = length(split(",", join(", ",data.aws_availability_zones.available.names)))
}


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}


resource "aws_vpc" "hashicorp_vpc" {
  cidr_block           = var.network_address_space
  enable_dns_hostnames = "true"

  tags = {
    Name = "${var.name}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.hashicorp_vpc.id

}

resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.hashicorp_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.name}-IGW"
  }

}

resource "aws_route_table_association" "vault-subnet" {
  count          = var.server_count
  subnet_id      = element(aws_subnet.vault_subnet.*.id, count.index)
  route_table_id = aws_route_table.rtb.id
}


resource "aws_subnet" "vault_subnet" {
  count                   = var.server_count
  vpc_id                  = aws_vpc.hashicorp_vpc.id
  cidr_block              = cidrsubnet(var.network_address_space, 8, count.index + 1)
  map_public_ip_on_launch = "true"
  availability_zone       = data.aws_availability_zones.available.names[count.index % local.mod_az]

  tags = {
    Name = "${var.name}-subnet"
  }
}

resource "aws_security_group" "primary" {
  name   = var.name
  vpc_id = aws_vpc.hashicorp_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.whitelist_ip]
  }


  # vault
  ingress {
    from_port   = 4646
    to_port     = 4648
    protocol    = "tcp"
    cidr_blocks = [var.whitelist_ip]
  }

  # Vault
  ingress {
    from_port   = 8200
    to_port     = 8202
    protocol    = "tcp"
    cidr_blocks = [var.whitelist_ip]
  }

  # Vault
  ingress {
    from_port   = 8300
    to_port     = 8302
    protocol    = "tcp"
    cidr_blocks = [var.whitelist_ip]
  }

  # Consul
  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = [var.whitelist_ip]
  }
  
  # Consul
  ingress {
    from_port   = 8600
    to_port     = 8600
    protocol    = "tcp"
    cidr_blocks = [var.whitelist_ip]
  }
  
  # Consul
  ingress {
    from_port   = 20000
    to_port     = 29999
    protocol    = "tcp"
    cidr_blocks = [var.whitelist_ip]
  }
  # Consul
  ingress {
    from_port   = 30000
    to_port     = 39999
    protocol    = "tcp"
    cidr_blocks = [var.whitelist_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}





resource "aws_iam_instance_profile" "vault_join" {
  name = var.name
  role = aws_iam_role.vault_join.name
}
resource "aws_iam_policy" "vault_join" {
  name = var.name
  description = "Allows vault nodes to describe instances for joining."
  policy = data.aws_iam_policy_document.vault-server.json
}
resource "aws_iam_role" "vault_join" {
  name = var.name
  assume_role_policy = data.aws_iam_policy_document.instance_role.json
}
resource "aws_iam_policy_attachment" "vault_join" {
  name = var.name
  roles      = [aws_iam_role.vault_join.name]
  policy_arn = aws_iam_policy.vault_join.arn
}
data "aws_iam_policy_document" "vault-server" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "VaultAWSAuthMethod"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "iam:GetInstanceProfile",
      "iam:GetUser",
      "iam:GetRole",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "VaultKMSUnseal"
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey",
    ]

    resources = ["*"]
  }
}

data "aws_iam_policy_document" "instance_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_kms_key" "kms_key_vault" {
 description             = "Vault KMS key"
}

resource "tls_private_key" "ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_self_signed_cert" "ca" {
  key_algorithm     = "${tls_private_key.ca.algorithm}"
  private_key_pem   = "${tls_private_key.ca.private_key_pem}"
  is_ca_certificate = true

  validity_period_hours = 12
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "server_auth",
  ]
  subject {
    common_name  = format("${var.server_name}-%02d", count.index + 1)
    organization = "${var.name}"
  }
}


output "vault_server_private_ips" {
  value = aws_instance.vault_server.*.private_ip
}

output "vault_server_public_ips" {
  value = aws_instance.vault_server[*].public_ip
}

