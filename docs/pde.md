
# rjayroach-coder

### macOS Host
- map Caps lock key to Control key
- enable remote access on Mac
- scp my credentials to the new Mac for GH repo access, etc

# Testing

- Enable passwordless sudo

```bash
mkdir ~/.ssh
wget -qO- https://github.com/rjayroach.keys > .ssh/authorized_keys
su -
apt install sudoers
echo 'ansible ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ansible
```

```bash
rm -rf $HOME/.cache/ppm $HOME/.local/bin/ppm
git clone git@github.com:maxcole/ppm.git $HOME/.cache/ppm
ln -s $HOME/.cache/ppm/ppm $HOME/.local/bin/ppm
echo 'git@github.com:maxcole/rjayroach-coder.git' > $HOME/.config/ppm/sources.list
ppm update
```

# ROADMAP

The goal is to be able to walk rainbow falls, listen to a podcast that claude put on my list, make a dictation or make a note in Obsidian in a specific file and back at the ranch claude code has already implmeented the change I called out in teh Obsidian doc


## nfs mount from MBP
- [ ]  use the network and nfs functions to create a ~/.config/coder/mounts
- [ ] use the nfs function to write the mount to MBP's /etc/fstab
- [ ] see that I can mount the remote host's projects path from the MBP

