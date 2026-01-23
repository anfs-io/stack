#!/bin/bash
exec > /root/postinstall.log 2>&1
set -x
# Post-installation script for default profile
# This script runs after the base system is installed via preseed late_command
set -e

export DEBIAN_FRONTEND=noninteractive
apt-get install -y zsh

# export PPM_INSTALL_REPO=git@github.com:maxcole/rjayroach
# export PPM_INSTALL_PACKAGES="zsh nvim tmux"
# curl -fsSL https://raw.githubusercontent.com/maxcole/ppm/refs/heads/main/install.sh | bash


echo "=== Post-installation script starting ==="
# Add custom post-installation commands here
echo "=== Post-installation complete ==="
touch ~/test.txt
touch /home/ansible/test2.txt
touch /root/test3.txt
