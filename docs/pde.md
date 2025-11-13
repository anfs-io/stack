
# rjayroach-coder

### macOS Host
- map Caps lock key to Control key
- enable remote access on Mac
- scp my credentials to the new Mac for GH repo access, etc


# ROADMAP

The goal is to be able to walk rainbow falls, listen to a podcast that claude put on my list, make a dictation or make a note in Obsidian in a specific file and back at the ranch claude code has already implmeented the change I called out in teh Obsidian doc


## one password
- [ ] on MBA have a look at the one password integration w/ chrome; disable lastpass and see if I can still "get things done"
- [ ] figure out how it is organized and maybe optimize it for business, etc
- [ ] gh and ssh integration with one password cli
- [ ] Create a one password package that ssh and gh invoke if coder profile is local
- [ ] Setup ssh package depends on coder_profile 
- [ ] 1password, ssh and gh for personal credentials and secrets
- [ ] Research 1password as an MFA replacement for Authy and how it handles passkeys
- [ ] watchtower
	- [ ] check for insecure passwords
	- [ ] which sites can be converted to passkeys
	- [ ] one time use card - can be used on a site instead of actual credit card details

## nfs mount from MBP
- [ ]  use the network and nfs functions to create a ~/.config/coder/mounts
- [ ] use the nfs function to write the mount to MBP's /etc/fstab
- [ ] see that I can mount the remote host's projects path from the MBP

## utm
- [ ] Coder to manage ISO files (port from the ventoy script)
- [ ] create a bunch of machines including omarchy using coder to download the ISOs
- [ ] create UTM base machines using some type of naming convention
- [ ] clone the base machines (with Apple script help) to then get the IP
- [ ] push the base images to the NAS when its ready to offer storage
