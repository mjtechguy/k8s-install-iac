#!/usr/bin/env bash

set -euo pipefail

# Detect distro (basic)
detect_distro() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$ID"
  else
    echo "unknown"
  fi
}

install_dependencies() {
  DISTRO=$(detect_distro)
  echo "[*] Installing dependencies for pipx on $DISTRO"

  case "$DISTRO" in
    ubuntu|debian)
      sudo apt update
      sudo apt install -y python3 python3-pip python3-venv curl
      ;;
    centos|rhel)
      sudo yum install -y python3 python3-pip python3-virtualenv curl
      ;;
    fedora)
      sudo dnf install -y python3 python3-pip python3-virtualenv curl
      ;;
    arch)
      sudo pacman -Sy --noconfirm python python-pip python-virtualenv curl
      ;;
    *)
      echo "[-] Unsupported distro: $DISTRO"
      exit 1
      ;;
  esac
}

install_pipx() {
  echo "[*] Installing pipx"
  python3 -m pip install --user pipx
  python3 -m pipx ensurepath

  # Reload shell environment if needed
  export PATH="$PATH:$HOME/.local/bin"
}

install_ansible() {
  echo "[*] Installing Ansible (full) via pipx"
  pipx install ansible
}

main() {
  install_dependencies
  install_pipx
  install_ansible
  echo "[+] All done! Run 'ansible --version' to verify."
}

main
