#!/bin/bash

tee /etc/profile.d/ips.sh > /dev/null <<EOF
function private_ip {
  curl -s http://169.254.169.254/latest/meta-data/local-ipv4
}
function public_ip {
  curl -s http://169.254.169.254/latest/meta-data/public-ipv4
}
EOF

source /etc/profile.d/ips.sh

timedatectl set-timezone UTC
apt-get -qq -y update
apt-get install -qq -y jq wget unzip dnsutils dnsmasq dnsmasq-base ntp
systemctl start ntp.service
systemctl enable ntp.service
curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
apt-get -qq -y update
apt-get install vault=${vault_version} consul=${consul_version}
