variable "aws_region" {
  description = "AWS region"
  default     = "eu-west-1"
}

variable "whitelist_ip" {
  default = "0.0.0.0/0"
}

variable "instance_type" {
  description = "type of EC2 instance to provision."
  default     = "t2.small"
}

variable "name" {
  description = "name to pass to Name tag"
  default     = "js-vault"
}

variable "key_name" {
  description = "SSH key to connect to EC2 instances. Use the one that is already uploaded into your AWS region or add one to main.tf"
  default     = "joestack"
}

variable "network_address_space" {
  description = "The default CIDR to use"
  default     = "172.16.0.0/16"
}


variable "server_count" {
  description = "amount of vault servers (odd number 1,3, max 5)"
  default     = "3"
}

variable "server_name" {
  default = "vault-s"
}


variable "tag_key" {
  description = "Server rejoin tag_key to identify vault servers within a region"
  default     = "js_vault_tag"
}

variable "tag_value" {
  description = "Server rejoin tag_value to identify vault servers within a region"
  default     = "js_vault_value"
}


variable "root_block_device_size" {
  default = "80"
}

# variable "ebs_block_device_size" {
#   default = "60"
# }

variable "vault_version" {
  default = "1.7.3"
}

variable "consul_version" {
  default = "1.10.0"
}

variable "dns_domain" {
  description = "DNS domain suffix"
  default     = "joestack.xyz"
}

variable "common_name" {
  description = "Cert common name"
  default     = "vault"
}

variable "organization" {
  description = "Cert Organaization"
  default     = "joestack"
}