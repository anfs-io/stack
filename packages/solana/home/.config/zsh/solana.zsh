# solana.zsh

# Add solana release path to the search path
ensure_path "$XDG_DATA_HOME/solana/install/active_release/bin"

# grind out vanity keypair(s) starting with <param>
solkg() {
    # Check if the first required parameter is missing
    if [[ -z "$1" ]]; then
        echo "Error: You must provide a prefix."
        echo "Usage: skg <prefix> [num_of_keys]"
        return 1
    fi

    # Set the second parameter, defaulting to 1 if not provided
    local num_keys="${2:-1}"

    echo "Starting Solana grind for prefix '$1' (Target: $num_keys key(s))..."

    # Run the solana-keygen command
    solana-keygen grind --starts-with "$1:$num_keys"
}
