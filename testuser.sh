#!/bin/bash
set -e

# Default options
FORCE=false
AUTO_SUDO=false
AUTO_DOCKER=false

# Parse command line options
while getopts "fsd" opt; do
   case $opt in
       f) FORCE=true ;;
       s) AUTO_SUDO=true ;;
       d) AUTO_DOCKER=true ;;
       \?) echo "Usage: $0 [-f] [-s] [-d] <username>"
           echo "  -f  Force creation (delete existing user without prompt)"
           echo "  -s  Automatically add to sudo group"
           echo "  -d  Automatically add to docker group (if exists)"
           exit 1 ;;
   esac
done

# Shift past the options to get the username
shift $((OPTIND-1))

# Check if username provided
if [ $# -eq 0 ]; then
   echo "Usage: $0 [-f] [-s] [-d] <username>"
   echo "  -f  Force creation (delete existing user without prompt)"
   echo "  -s  Automatically add to sudo group"
   echo "  -d  Automatically add to docker group (if exists)"
   exit 1
fi

NEW_USER="$1"
CURRENT_USER="$USER"

# Check if user already exists
if id "$NEW_USER" &>/dev/null; then
   if [ "$FORCE" = true ]; then
       echo "Force option enabled. Deleting existing user '$NEW_USER'..."
       # Kill any processes owned by the user
       sudo pkill -u "$NEW_USER" || true
       
       # Remove the user and their home directory
       sudo userdel -r "$NEW_USER" 2>/dev/null || {
           echo "Warning: Could not remove home directory, continuing..."
           sudo userdel "$NEW_USER"
       }
       echo "User '$NEW_USER' deleted."
   else
       echo "User '$NEW_USER' already exists."
       read -p "Do you want to delete the existing user and recreate? (y/N): " -n 1 -r
       echo
       if [[ $REPLY =~ ^[Yy]$ ]]; then
           # Kill any processes owned by the user
           sudo pkill -u "$NEW_USER" || true
           
           # Remove the user and their home directory
           sudo userdel -r "$NEW_USER" 2>/dev/null || {
               echo "Warning: Could not remove home directory, continuing..."
               sudo userdel "$NEW_USER"
           }
           echo "User '$NEW_USER' deleted."
       else
           echo "Exiting without changes."
           exit 0
       fi
   fi
fi

# Create the new user with home directory
sudo adduser --disabled-password --gecos "" "$NEW_USER"

# Copy SSH authorized_keys if it exists
if [ -f "/home/$CURRENT_USER/.ssh/authorized_keys" ]; then
   # Create .ssh directory for new user
   sudo mkdir -p "/home/$NEW_USER/.ssh"
   
   # Copy authorized_keys
   sudo cp "/home/$CURRENT_USER/.ssh/authorized_keys" "/home/$NEW_USER/.ssh/"
   
   # Set proper ownership and permissions
   sudo chown -R "$NEW_USER:$NEW_USER" "/home/$NEW_USER/.ssh"
   sudo chmod 700 "/home/$NEW_USER/.ssh"
   sudo chmod 600 "/home/$NEW_USER/.ssh/authorized_keys"
   
   echo "SSH keys copied for user $NEW_USER"
else
   echo "Warning: No authorized_keys file found for $CURRENT_USER"
fi

# Copy bootstrap.sh if it exists in current directory
if [ -f "./bootstrap.sh" ]; then
   sudo cp "./bootstrap.sh" "/home/$NEW_USER/"
   sudo chown "$NEW_USER:$NEW_USER" "/home/$NEW_USER/bootstrap.sh"
   sudo chmod +x "/home/$NEW_USER/bootstrap.sh"
   echo "bootstrap.sh copied to $NEW_USER's home directory"
else
   echo "Warning: bootstrap.sh not found in current directory"
fi

# Create .inputrc with vi mode settings
sudo tee "/home/$NEW_USER/.inputrc" > /dev/null << 'EOF'
set editing-mode vi
set show-mode-in-prompt on
EOF

# Set proper ownership for .inputrc
sudo chown "$NEW_USER:$NEW_USER" "/home/$NEW_USER/.inputrc"
echo ".inputrc created with vi mode settings for user $NEW_USER"

# Handle sudo group
if [ "$AUTO_SUDO" = true ]; then
   sudo usermod -aG sudo "$NEW_USER"
   echo "User $NEW_USER added to sudo group"
else
   read -p "Add $NEW_USER to sudo group? (y/N): " -n 1 -r
   echo
   if [[ $REPLY =~ ^[Yy]$ ]]; then
       sudo usermod -aG sudo "$NEW_USER"
       echo "User $NEW_USER added to sudo group"
   fi
fi

# Handle docker group
if [ "$AUTO_DOCKER" = true ]; then
   if getent group docker >/dev/null 2>&1; then
       sudo usermod -aG docker "$NEW_USER"
       echo "User $NEW_USER added to docker group"
   else
       echo "Warning: docker group does not exist, skipping"
   fi
else
   # Only ask about docker if the group exists
   if getent group docker >/dev/null 2>&1; then
       read -p "Add $NEW_USER to docker group? (y/N): " -n 1 -r
       echo
       if [[ $REPLY =~ ^[Yy]$ ]]; then
           sudo usermod -aG docker "$NEW_USER"
           echo "User $NEW_USER added to docker group"
       fi
   fi
fi

echo "User $NEW_USER created successfully"
