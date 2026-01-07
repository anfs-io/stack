# utm

alias utm-ls='utmctl list'
alias utm-start='utmctl start'
alias utm-stop='utmctl stop'
alias utm-status='utmctl status'
alias utm-clone='utmctl clone'
alias utm-delete='utmctl delete'

# Get IPv4 address of UTM VM (no newline)
utm-ip() { utmctl ip-address "$1" | grep -v ':' | tr -d '\n' }

# SSH into UTM VM by name
utm-ssh() { ssh "$(utm-ip "$1")" }

# Quick VM operations
alias utmdev='utmctl start "Development VM" && sleep 10 && utmctl ip-address "Development VM"'


# Clone and randomize a VM
function utm_clone_vm() {
    local template_name="$1"
    local clone_name="${template_name}-$(date +%s)"
    
    echo "Cloning $template_name to $clone_name..."
    utmctl clone "$template_name" --name "$clone_name"
    
    echo "Randomizing MAC address..."
    osascript <<END
tell application "UTM"
    set vm to virtual machine named "$clone_name"
    set config to configuration of vm
    set item 1 of network interfaces of config to {address:""}
    update configuration of vm with config
end tell
END
    
    echo "Starting VM..."
    utmctl start "$clone_name"
    
    echo "Waiting for boot..."
    sleep 30
    
    echo "VM IP addresses:"
    utmctl ip-address "$clone_name"
    
    echo "Clone complete: $clone_name"
}
