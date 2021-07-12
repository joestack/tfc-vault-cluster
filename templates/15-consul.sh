#!/bin/bash

apt-get install -qq -y dnsmasq-base dnsmasq consul=${consul_version}

tee ${consul_env_vars} > /dev/null <<ENVVARS
#FLAGS=-dev -enable-script-checks -ui -client 0.0.0.0
FLAGS=
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

cat <<EOF >${systemd_dir}/consul.service
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

sudo systemctl enable consul
sudo systemctl start consul


