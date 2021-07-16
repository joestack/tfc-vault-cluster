apt-get install vault=${vault_version}

tee ${vault_env_vars} > /dev/null <<ENVVARS
#FLAGS=-dev -dev-ha -dev-transactional -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200
FLAGS=
ENVVARS

cat <<EOF >${vault_config_dir}/vault.hcl
# Full configuration options can be found at https://www.vaultproject.io/docs/configuration

listener "tcp" {
    address = "0.0.0.0:8200"
    cluster_address= "0.0.0.0:8201"
    tls_cert_file = "/etc/ssl/certs/fullchain.crt"
    tls_key_file  = "/etc/ssl/certs/privkey.key"
    #tls_disable = "true"
}

storage "raft" {
    path = "/opt/vault/data"

    node_id = "${node_name}"

    retry_join {
        leader_tls_servername = "${node_name}.${dns_domain}"
        auto_join = "provider=aws tag_key=vault_join tag_value=${vault_join}"
    }
}

seal "awskms" {
  region     = "${region}"
  kms_key_id = "${kms_key_id}"
}


# storage "file" {
#     path = "/opt/vault/data"
# }

ui = true

disable_mlock = true

#cluster_addr = "https://${node_name}:8201"
cluster_addr = "https://$(private_ip):8201"

api_addr = "https://${node_name}.${dns_domain}:8200"

EOF

tee ${vault_profile_script} > /dev/null <<PROFILE
export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_TOKEN=
PROFILE

setcap cap_ipc_lock=+ep ${vault_path}

cat <<EOF >${systemd_dir}/vault.service
[Unit]
Description=Vault Agent
#Requires=consul-online.target
#After=consul-online.target

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

sudo mkdir --parents /etc/vault.d
sudo echo "${cert}" > /etc/ssl/certs/fullchain.crt
sudo echo "${key}" > /etc/ssl/certs/privkey.key
sudo echo "${ca_cert}" > /etc/ssl/certs/ca.crt



systemctl enable vault
systemctl start vault
#vault operator init
