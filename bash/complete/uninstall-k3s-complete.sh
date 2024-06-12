#!/bin/bash

# Prompt the user for confirmation
read -p "Are you sure you want to uninstall k3s and remove associated tools? Type 'yes' to proceed: " confirm_uninstall

if [ "$confirm_uninstall" == "yes" ]; then
    # Uninstall k3s
    /usr/local/bin/k3s-uninstall.sh

    # Remove the copied kubeconfig file
    rm -f $HOME/.kube/config

    # Uninstall k9s
    if command -v k9s &> /dev/null; then
        sudo rm -f /usr/local/bin/k9s
        echo "k9s has been uninstalled."
    else
        echo "k9s is not installed."
    fi

    # Uninstall Helm
    if command -v helm &> /dev/null; then
        sudo rm -f /usr/local/bin/helm
        echo "Helm has been uninstalled."
    else
        echo "Helm is not installed."
    fi

    # Uninstall kubectl
    if command -v kubectl &> /dev/null; then
        sudo rm -f /usr/local/bin/kubectl
        echo "kubectl has been uninstalled."
    else
        echo "kubectl is not installed."
    fi

    echo "k3s and associated tools have been uninstalled."
else
    echo "Uninstall cancelled."
fi
