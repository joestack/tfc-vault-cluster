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
    tls_disable = "true"
    #tls_cert_file = "/vault/certs/vault_cert.pem"
    #tls_key_file = "/vault/certs/vault_key.key"
}

storage "raft" {
    path = "/opt/vault/data"

    node_id = "${node_name}"

    retry_join {
        leader_api_addr = "https://${node_name}:8200"
    }
}

# storage "file" {
#     path = "/opt/vault/data"
# }

ui = true

disable_mlock = true

cluster_addr = "https://${node_name}:8201"

api_addr = "https://${node_name}:8200"

EOF

tee ${vault_profile_script} > /dev/null <<PROFILE
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root
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

systemctl enable vault
systemctl start vault
