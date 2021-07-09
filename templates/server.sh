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

tee ${consul_env_vars} > /dev/null <<ENVVARS
FLAGS=-dev -enable-script-checks -ui -client 0.0.0.0
CONSUL_HTTP_ADDR=http://127.0.0.1:8500
ENVVARS

tee ${consul_profile_script} > /dev/null <<PROFILE
export CONSUL_HTTP_ADDR=http://127.0.0.1:8500
PROFILE

sed -i '1i nameserver 127.0.0.1\n' /etc/resolv.conf

tee /etc/dnsmasq.d/consul > /dev/null <<DNSMASQ
server=/consul/127.0.0.1#8600
DNSMASQ

systemctl enable dnsmasq
systemctl restart dnsmasq

at <<EOF >${systemd_dir}/consul.service
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/consul.hcl

[Service]
User=consul
Group=consul
EnvironmentFile=/etc/consul.d/consul.conf
ExecStart=/usr/bin/consul agent -config-dir=/etc/consul.d/ \$FLAGS
ExecReload=/bin/kill --signal HUP \$MAINPID
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl enable consul
systemctl start consul


tee ${vault_env_vars} > /dev/null <<ENVVARS
FLAGS=-dev -dev-ha -dev-transactional -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200
ENVVARS

cat <<EOF >${vault_config_dir}/vault.hcl
# Full configuration options can be found at https://www.vaultproject.io/docs/configuration

ui = true

#mlock = true
#disable_mlock = true

#storage "file" {
#  path = "/opt/vault/data"
#}

storage "consul" {
  address = "127.0.0.1:8500"
  path    = "vault"
}

# HTTP listener
#listener "tcp" {
#  address = "127.0.0.1:8200"
#  tls_disable = 1
#}

# HTTPS listener
#listener "tcp" {
#  address       = "0.0.0.0:8200"
#  tls_cert_file = "/opt/vault/tls/tls.crt"
#  tls_key_file  = "/opt/vault/tls/tls.key"
#}

# Example AWS KMS auto unseal
#seal "awskms" {
#  region = "us-east-1"
#  kms_key_id = "REPLACE-ME"
#}

# Example HSM auto unseal
#seal "pkcs11" {
#  lib            = "/usr/vault/lib/libCryptoki2_64.so"
#  slot           = "0"
#  pin            = "AAAA-BBBB-CCCC-DDDD"
#  key_label      = "vault-hsm-key"
#  hmac_key_label = "vault-hsm-hmac-key"
#}
EOF

tee ${vault_profile_script} > /dev/null <<PROFILE
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root
PROFILE

setcap cap_ipc_lock=+ep ${vault_path}

cat <<EOF >${systemd_dir}/vault.service
[Unit]
Description=Vault Agent
Requires=consul-online.target
After=consul-online.target

[Service]
Restart=on-failure
EnvironmentFile=/etc/vault.d/vault.conf
PermissionsStartOnly=true
ExecStartPre=/sbin/setcap 'cap_ipc_lock=+ep' /usr/bin/vault
ExecStart=/usr/bin/vault server -config /etc/vault.d \$FLAGS
ExecReload=/bin/kill -HUP \$MAINPID
KillSignal=SIGTERM
User=vault
Group=vault
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > ${systemd_dir}/consul-online.service
[Unit]
Description=Consul Online
Requires=consul.service
After=consul.service

[Service]
Type=oneshot
ExecStart=/usr/bin/consul-online.sh
User=consul
Group=consul

[Install]
WantedBy=consul-online.target multi-user.target
EOF

cat <<EOF > ${systemd_dir}/consul-online.target
[Unit]
Description=Consul Online
RefuseManualStart=true
EOF

cat <<EOF > ${systemd_dir}/consul-online.sh

#!/bin/bash

set -e
set -o pipefail


# waitForConsulToBeAvailable loops until the local Consul agent returns a 200
# response at the /v1/operator/raft/configuration endpoint.
#
# Parameters:
#     None
function waitForConsulToBeAvailable() {
  local consul_http_addr=$1
  local consul_leader_http_code

  consul_leader_http_code=$(curl --silent --output /dev/null --write-out "%{http_code}" "${consul_http_addr}/v1/operator/raft/configuration") || consul_leader_http_code=""

  while [ "x${consul_leader_http_code}" != "x200" ] ; do
    echo "Waiting for Consul to get a leader..."
    sleep 5
    consul_leader_http_code=$(curl --silent --output /dev/null --write-out "%{http_code}" "${consul_http_addr}/v1/operator/raft/configuration") || consul_leader_http_code=""
  done
}

waitForConsulToBeAvailable "${consul_http_addr}"
EOF

systemctl enable consul
systemctl start consul
systemctl enable vault
systemctl start vault
