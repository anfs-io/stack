#!/bin/bash
# bootstrap.sh
set -e

if [[ "$*" == *"-s"* ]]; then
    # Install ansible
    # sudo apt update
    sudo apt install -y ansible git
    
    # Clone roles repo (if not already present)
    if [ ! -d "/etc/ansible/roles" ]; then
        sudo mkdir -p /etc/ansible
        sudo chown $(whoami):$(whoami) /etc/ansible
        cd /etc/ansible
        git clone git@github.com:maxcole/ansible.git roles
    fi
fi


# Clone your config repo (if not already present)
if [ ! -d "config" ]; then
    git clone git@github.com:maxcole/config.git
fi

cd config

# Run your main playbook
ansible-playbook -i localhost, -c local site.yml # --ask-become-pass

