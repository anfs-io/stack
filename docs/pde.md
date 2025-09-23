
## Deployment Types

### macOS Host (user roberto)

- May have been adopted (or 
- May be actively managed

- will have ssh private keys

### Linux Development Host (user roberto)

- May have been adopted
- May be actively managed
- May be a Control Host


### Linux Control Host (user ansible)

- Must be adopted
- Must be actively managed



ssh credentials for GH repo access

sudo priviledges


## Commands

```bash
wget -qO- https://raw.githubusercontent.com/maxcole/rjayroach-home/refs/heads/main/install.sh | bash -s -- all
```

sudo echo "ansible ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible
