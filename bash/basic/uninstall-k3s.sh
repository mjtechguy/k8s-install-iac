#!/bin/bash

# Prompt the user for confirmation
read -p "Are you sure you want to uninstall k3s? This will delete ALL data and running pods in the deployment. Type 'yes' to proceed: " confirm_uninstall

if [ "$confirm_uninstall" == "yes" ]; then
    # Uninstall k3s
    /usr/local/bin/k3s-uninstall.sh
    echo "k3s has been uninstalled."

    # Remove the copied kubeconfig file
    rm -f $HOME/.kube/config
else
    echo "Uninstall cancelled."
fi
