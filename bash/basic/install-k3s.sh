#!/bin/bash

# Function to prompt for a variable if not set
prompt_if_unset() {
    local var_name=$1
    local var_value=$(eval echo \$$var_name)
    if [ -z "$var_value" ]; then
        read -p "Enter $var_name: " var_value
        export $var_name=$var_value
    fi
}

# Load variables from .env file
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Prompt for missing variables
prompt_if_unset K3S_VERSION
prompt_if_unset TLS_SANS
prompt_if_unset DISABLE_TRAEFIK
prompt_if_unset KUBECONFIG_PATH

# Determine whether to disable Traefik
DISABLE_TRAEFIK_OPTION=""
if [ "$DISABLE_TRAEFIK" = "true" ]; then
    DISABLE_TRAEFIK_OPTION="--disable traefik"
fi

# Convert comma-separated TLS SANs into multiple --tls-san options
IFS=',' read -r -a SAN_ARRAY <<< "$TLS_SANS"
TLS_SAN_OPTIONS=""
for SAN in "${SAN_ARRAY[@]}"; do
    TLS_SAN_OPTIONS+=" --tls-san $SAN"
done

# Install k3s with the specified variables
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${K3S_VERSION} sh -s - \
    $DISABLE_TRAEFIK_OPTION \
    $TLS_SAN_OPTIONS

# Save the kubeconfig and update the server IP to the first SAN IP
KUBECONFIG_PATH_DEFAULT="/etc/rancher/k3s/k3s.yaml"
KUBECONFIG_PATH=${KUBECONFIG_PATH:-$KUBECONFIG_PATH_DEFAULT}

# Copy the kubeconfig to the desired location
sudo cp $KUBECONFIG_PATH $HOME/.kube/config

# Update the server IP in the kubeconfig
FIRST_SAN=$(echo $TLS_SANS | cut -d',' -f1)
sed -i "s/127.0.0.1/$FIRST_SAN/g" $HOME/.kube/config

# Print installation details
echo "k3s installed with the following details:"
echo "Version: ${K3S_VERSION}"
echo "TLS SANs: ${TLS_SANS}"
echo "Traefik: Disabled ($DISABLE_TRAEFIK)"
echo "Kubeconfig saved to: $HOME/.kube/config with server IP updated to $FIRST_SAN"
