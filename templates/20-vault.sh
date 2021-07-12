apt-get install vault=${vault_version}

tee ${vault_env_vars} > /dev/null <<ENVVARS
FLAGS=-dev -dev-ha -dev-transactional -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200
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

    node_id = "server1"

    retry_join {
        leader_api_addr = "https://server1:8200"
    }
}

ui = true

disable_mlock = true

cluster_addr = "https://server1:8201"

api_addr = "https://server1:8200"

EOF

tee ${vault_profile_script} > /dev/null <<PROFILE
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root
PROFILE

setcap cap_ipc_lock=+ep ${vault_path}
