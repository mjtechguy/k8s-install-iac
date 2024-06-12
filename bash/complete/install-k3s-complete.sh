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
prompt_if_unset INGRESS_NGINX_REPLICAS
prompt_if_unset HELM_VERSION
prompt_if_unset KUBECTL_VERSION
prompt_if_unset K9S_VERSION
prompt_if_unset RANCHER_VERSION
prompt_if_unset RANCHER_HOSTNAME
prompt_if_unset LETSENCRYPT_EMAIL

# Install kubectl
if ! command -v kubectl &> /dev/null; then
    echo "kubectl not found, installing version $KUBECTL_VERSION..."
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
else
    echo "Kubectl is already installed."
    INSTALLED_VERSION=$(kubectl version --short | grep Version | awk '{print $2}')
    echo "Installed version: $INSTALLED_VERSION"
fi

# Install helm
if ! command -v helm &> /dev/null; then
    echo "helm not found, installing version $HELM_VERSION..."
    curl -LO "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"
    tar -zxvf helm-${HELM_VERSION}-linux-amd64.tar.gz
    sudo mv linux-amd64/helm /usr/local/bin/helm
    rm helm-${HELM_VERSION}-linux-amd64.tar.gz
    rm -r linux-amd64
else
    echo "Helm is already installed."
    INSTALLED_VERSION=$(helm version --short | grep Version | awk '{print $2}')
    echo "Installed version: $INSTALLED_VERSION"
fi

# Install k9s
if ! command -v k9s &> /dev/null; then
    echo "k9s not found, installing version $K9S_VERSION..."
    curl -Lo k9s.tar.gz "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz"
    tar -xzf k9s.tar.gz k9s
    chmod +x k9s
    sudo mv k9s /usr/local/bin/
    rm k9s.tar.gz
    echo "k9s version $K9S_VERSION installed successfully."
else
    echo "k9s is already installed."
    INSTALLED_VERSION=$(k9s version --short | grep Version | awk '{print $2}')
    echo "Installed version: $INSTALLED_VERSION"
fi

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
echo "Copying kubeconfig to $HOME/.kube/config..."
mkdir $HOME/.kube/
sudo cp $KUBECONFIG_PATH $HOME/.kube/config

# Update the server IP in the kubeconfig
FIRST_SAN=$(echo $TLS_SANS | cut -d',' -f1)
sed -i "s/127.0.0.1/$FIRST_SAN/g" $HOME/.kube/config

# Sleep for 30 seconds to allow k3s to fully initialize
sleep 30

# Deploy ingress-nginx using Helm with the specified number of replicas
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.replicaCount=${INGRESS_NGINX_REPLICAS} \
  --set controller.ingressClassResource.default=true

# Install cert-manager
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo update
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.15.0 \
  --set crds.enabled=true \
  --set 'extraArgs={--dns01-recursive-nameservers-only,--dns01-recursive-nameservers=8.8.8.8:53\,1.1.1.1:53,1.0.0.1:53}'

# Verify cert-manager installation
kubectl rollout status deployment cert-manager -n cert-manager
kubectl rollout status deployment cert-manager-webhook -n cert-manager
kubectl rollout status deployment cert-manager-cainjector -n cert-manager

# Sleep for 30 seconds to allow cert-manager to fully initialize
sleep 30

# Create Rancher Namespace
kubectl create namespace cattle-system

# Install Rancher with Let's Encrypt using Helm
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo update

helm upgrade --install rancher rancher-stable/rancher \
  --namespace cattle-system --create-namespace \
  --set hostname=${RANCHER_HOSTNAME} \
  --set ingress.tls.source=letsEncrypt \
  --set letsEncrypt.email=${LETSENCRYPT_EMAIL} \
  --set letsEncrypt.ingress.class=nginx \
  --version ${RANCHER_VERSION} \
  --set bootstrapPassword=${RANCHER_PASSWORD} \
  --set replicas=${RANCHER_REPLICAS}

# Verify Rancher installation
kubectl -n cattle-system rollout status deploy/rancher

# Function to check if a Kubernetes secret exists
check_secret_exists() {
  local secret_name=$1
  local namespace=$2
  kubectl get secret $secret_name -n $namespace &> /dev/null
}

# Create the Cloudflare API key secret
kubectl create secret generic cloudflare-api-key-secret \
  --from-literal=api-token=${CLOUDFLARE_API_KEY} -n cert-manager

# Determine Let's Encrypt server based on environment
if [ "$LETSENCRYPT_ENV" = "prod" ]; then
    LETSENCRYPT_SERVER="https://acme-v02.api.letsencrypt.org/directory"
else
    LETSENCRYPT_SERVER="https://acme-staging-v02.api.letsencrypt.org/directory"
fi

# Define the ClusterIssuer YAML
read -r -d '' CLUSTER_ISSUER_YAML << EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns01-issuer
spec:
  acme:
    server: ${LETSENCRYPT_SERVER}
    email: ${LETSENCRYPT_EMAIL}
    privateKeySecretRef:
      name: letsencrypt-dns01-private-key
    solvers:
    - dns01:
        cloudflare:
          apiTokenSecretRef:
            name: cloudflare-api-key-secret
            key: api-token
EOF

# Apply the ClusterIssuer
echo "$CLUSTER_ISSUER_YAML" | kubectl apply -f -

# Request Wildcard Certificate using Cloudflare DNS01 Challenge
read -r -d '' WILDCARD_CERT_YAML << EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: default-wildcard-tls
  namespace: default
spec:
  secretTemplate:
    annotations:
      reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
      reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: ""
  secretName: default-wildcard-tls-cert
  issuerRef:
    name: letsencrypt-dns01-issuer
    kind: ClusterIssuer
  commonName: ${BASE_DOMAIN}
  dnsNames:
  - '${WILDCARD_DOMAIN}'
EOF

# Apply the Wildcard Certificate
echo "$WILDCARD_CERT_YAML" | kubectl apply -f -

# Wait for the certificate secret to be created
echo "Waiting for certificate to be issued..."
CERT_SECRET_NAME="default-wildcard-tls-cert"
NAMESPACE="default"
for i in {1..30}; do
  if check_secret_exists $CERT_SECRET_NAME $NAMESPACE; then
    echo "Certificate secret $CERT_SECRET_NAME found in namespace $NAMESPACE."
    break
  fi
  echo "Certificate secret not found yet. Retrying in 10 seconds..."
  sleep 10
done

# Check if the certificate secret exists
if ! check_secret_exists $CERT_SECRET_NAME $NAMESPACE; then
  echo "Certificate secret $CERT_SECRET_NAME not found after waiting. Exiting script."
  exit 1
fi

echo "Certificate has been issued successfully."

# Install Kubernetes Reflector
helm repo add emberstack https://emberstack.github.io/helm-charts
helm repo update
helm upgrade --install reflector emberstack/reflector

# Print installation details
echo "k3s installed with the following details:"
echo "Version: ${K3S_VERSION}"
echo "TLS SANs: ${TLS_SANS}"
echo "Traefik: Disabled ($DISABLE_TRAEFIK)"
echo "Kubeconfig saved to: $HOME/.kube/config with server IP updated to $FIRST_SAN"
echo "Ingress NGINX deployed with the following details:"
echo "Number of replicas: ${INGRESS_NGINX_REPLICAS}"
echo "cert-manager installed successfully."
echo "Rancher installed with the following details:"
echo "Version: ${RANCHER_VERSION}"
echo "Hostname: ${RANCHER_HOSTNAME}"
echo "Let's Encrypt Email: ${LETSENCRYPT_EMAIL}"
