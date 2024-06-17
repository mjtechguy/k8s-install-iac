# K8s Deployment IAC

This repository contains the IAC for deploying a single node Kubernetes cluster on using Ansible.

The intention of this playbook is to deploy a full k3s/rke2 cluster with all the necessary components to run a production ready cluster. This includes a wildcard certificate for the cluster, an Nginx Ingress Controller, Helm, and Rancher MCM UI. The Reflector tool is also installed to copy the wildcard certificate to all namespaces for use with other applications.

## Components

- k3s/rke2
- k9s
- kubectl
- Helm
- Nginx Ingress Controller
- Cert-Manager
- Rancher MCM UI
- Reflector

## Prerequisites

- Public facing server with Ubuntu 22.04 installed
- Ansible
- Python
- Cloudflare DNS with appropriate DNS names pointing at your server and an API key for DNS modification by cert-manager.

## Usage

1. Clone the repository
2. Copy `ansible/inventory/group_vars/all.example` to `ansible/inventory/group_vars/all` and update the variables. Note that if you want to test cert generation, please change the `letsencrypt_env` to `dev` and update the `letsencrypt_email` to your email address. When you are ready to deploy to production, change the `letsencrypt_env` to `prod`.
3. `cd` into `ansible` Run the playbook
4. Run the playbook `ansible-playbook main.yml`

## Deploy a test application

1. Run `ansible-playbook main.yml --tags test` and a https protected nginx deployment will be deployed to the cluster using the `wildcard` certificate to ensure it is working

## Remove the test application

1. Run `ansible-playbook main.yml --tags remove-test` to remove the test application and the wildcard certificate

## Cleanup

1. Run `ansible-playbook main.yml --tags cleanup` to remove all the components including k3s/rke2 (which also removes all deployments, certs, etc)