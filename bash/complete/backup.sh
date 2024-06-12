#!/bin/bash

# Function to create a timestamped backup file
create_backup() {
    local timestamp=$(date +"%Y%m%d%H%M%S")
    local backup_file="backup_${timestamp}.txt"

    cat << EOF > $backup_file
K3S_VERSION=${K3S_VERSION}
TLS_SANS=${TLS_SANS}
DISABLE_TRAEFIK=${DISABLE_TRAEFIK}
KUBECONFIG_PATH=${KUBECONFIG_PATH}
INGRESS_NGINX_REPLICAS=${INGRESS_NGINX_REPLICAS}
HELM_VERSION=${HELM_VERSION}
KUBECTL_VERSION=${KUBECTL_VERSION}
K9S_VERSION=${K9S_VERSION}
RANCHER_VERSION=${RANCHER_VERSION}
RANCHER_HOSTNAME=${RANCHER_HOSTNAME}
LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}
BASE_DOMAIN=${BASE_DOMAIN}
WILDCARD_DOMAIN=${WILDCARD_DOMAIN}
EOF

    echo "Backup created at $backup_file"
}

# Call the backup function
create_backup
