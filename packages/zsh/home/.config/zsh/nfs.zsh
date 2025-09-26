#!/bin/zsh

# Function 3: NFS scanner with optional subnet (defaults to local)
scan_nfs() {
    local subnet="${1:-$(get_local_subnet)}"
    
    if [[ -z "$subnet" ]]; then
        echo "Error: Could not determine subnet" >&2
        return 1
    fi
    
    # echo "Scanning $subnet for NFS services..." >&2
    scan_ports "$subnet" 2049 20048
}

# Function 4: Get NFS exports from hosts
# Usage: get_nfs_exports host1 [host2] [host3] ...
# Or: get_nfs_exports $(scan_nfs)
get_nfs_exports() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: get_nfs_exports host1 [host2] [host3] ..." >&2
        echo "Example: get_nfs_exports \$(scan_nfs)" >&2
        return 1
    fi
    
    if [[ "$CODER_OUT" == "debug" ]]; then
        echo "Debug: Checking NFS exports on $# hosts" >&2
    fi
    
    local exports_found=""
    
    for host in "$@"; do
        if [[ -n "$host" ]]; then
            if [[ "$CODER_OUT" == "debug" ]]; then
                echo "Debug: Querying exports from $host" >&2
            fi
            
            if command -v showmount >/dev/null 2>&1; then
                local host_exports=$(showmount -e "$host" 2>/dev/null | tail -n +2 | awk '{print "'$host':" $1}')
                if [[ -n "$host_exports" ]]; then
                    exports_found="${exports_found}${host_exports}\n"
                    if [[ "$CODER_OUT" == "debug" ]]; then
                        echo "Debug: Found exports on $host:" >&2
                        echo "$host_exports" >&2
                    fi
                else
                    if [[ "$CODER_OUT" == "debug" ]]; then
                        echo "Debug: No exports found on $host" >&2
                    fi
                fi
            else
                if [[ "$CODER_OUT" == "debug" ]]; then
                    echo "Debug: showmount not available (install nfs-common/nfs-utils)" >&2
                fi
                return 1
            fi
        fi
    done
    
    # Return results (remove trailing newline)
    echo -e "$exports_found" | sed '/^$/d'
}

# Function 5: Mount NFS exports and optionally add to fstab
# Usage: mount_nfs_exports [--fstab] export1 [export2] ...
# Export format: "host:/path"
mount_nfs_exports() {
    local add_to_fstab=false
    local exports=()
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --fstab)
                add_to_fstab=true
                shift
                ;;
            *)
                exports+=("$1")
                shift
                ;;
        esac
    done
    
    if [[ ${#exports[@]} -eq 0 ]]; then
        echo "Usage: mount_nfs_exports [--fstab] export1 [export2] ..." >&2
        echo "Export format: host:/path or get from get_nfs_exports output" >&2
        echo "Example: mount_nfs_exports \$(get_nfs_exports \$(scan_nfs))" >&2
        return 1
    fi
    
    if [[ "$CODER_OUT" == "debug" ]]; then
        echo "Debug: Mounting ${#exports[@]} NFS exports" >&2
        if [[ "$add_to_fstab" == "true" ]]; then
            echo "Debug: Will add entries to /etc/fstab" >&2
        fi
    fi
    
    local mounted_exports=""
    
    for export in "${exports[@]}"; do
        if [[ -n "$export" ]]; then
            # Parse host:path format
            local host_path="$export"
            local mount_name=$(echo "$host_path" | tr ':/' '__' | sed 's/__$//')
            local mount_point="/mnt/nfs_${mount_name}"
            
            if [[ "$CODER_OUT" == "debug" ]]; then
                echo "Debug: Mounting $host_path at $mount_point" >&2
            fi
            
            # Create mount point
            sudo mkdir -p "$mount_point" 2>/dev/null
            
            # Mount the export
            if sudo mount -t nfs "$host_path" "$mount_point" 2>/dev/null; then
                mounted_exports="${mounted_exports}${mount_point}\n"
                
                if [[ "$CODER_OUT" == "debug" ]]; then
                    echo "Debug: Successfully mounted $host_path at $mount_point" >&2
                fi
                
                # Add to fstab if requested
                if [[ "$add_to_fstab" == "true" ]]; then
                    local fstab_entry="$host_path $mount_point nfs defaults 0 0"
                    
                    # Check if entry already exists
                    if ! grep -q "$host_path" /etc/fstab 2>/dev/null; then
                        echo "$fstab_entry" | sudo tee -a /etc/fstab >/dev/null
                        if [[ "$CODER_OUT" == "debug" ]]; then
                            echo "Debug: Added to /etc/fstab: $fstab_entry" >&2
                        fi
                    else
                        if [[ "$CODER_OUT" == "debug" ]]; then
                            echo "Debug: Entry already exists in /etc/fstab for $host_path" >&2
                        fi
                    fi
                fi
            else
                if [[ "$CODER_OUT" == "debug" ]]; then
                    echo "Debug: Failed to mount $host_path" >&2
                fi
            fi
        fi
    done
    
    # Return mounted paths (remove trailing newline)
    echo -e "$mounted_exports" | sed '/^$/d'
}

