#!/usr/bin/env bash

set -euo pipefail

clear

if ! [ "${UID}" -eq 1000 ]; then
    echo "This script must be run as the user with UID 1000."
    echo "Press ESC to exit..."
    wait_for_escape
    exit 0
fi

wait_for_escape() {
    while true; do
        read -rsn1 key
        if [[ $key == $'\e' ]]; then
            echo
            break
        fi
    done
}

STAMP_PATH="$HOME/.local/state/dank-blue-build-personal"
mkdir -p "$STAMP_PATH"

if [[ -f "$STAMP_PATH/desktop-setup-done" ]]; then
    echo "Setup has already been completed."
    echo "Press ESC to exit..."
    wait_for_escape
    exit 0
fi

echo "Running setup script for user ${USER} in terminal emulator ${TERMINAL}..."

if [[ -f "$STAMP_PATH/sync-dankgreeter-done" ]]; then
    echo "DankGreeter has already been synced."
else
    echo "Syncing DankGreeter..."
    if dms greeter sync; then
        echo "Successfully synced DankGreeter."
        touch "$STAMP_PATH/sync-dankgreeter-done"
    else
        echo "Failed to sync DankGreeter. Proceeding to backup restoration instead..." >&2
    fi      
fi

echo "Attempting to restore ${USER}'s backup..."

TEMP_MOUNTPOINT=$(mktemp -d)
mount -o subvolid=5 -L WD-1TB ${TEMP_MOUNTPOINT}
cleanup() {
    umount "$TEMP_MOUNTPOINT" 2>/dev/null || true
    rmdir "$TEMP_MOUNTPOINT" 2>/dev/null || true
}
trap cleanup EXIT
echo "Temporarily mounted WD-1TB at '${TEMP_MOUNTPOINT}'."

if btrfs subvolume list "$TEMP_MOUNTPOINT"  | awk '{print $NF}' | grep -qx "@samsung_backup"; then
    echo "Verified that Btrfs subvolume '@samsung_backup' exists in WD-1TB."
else
    echo "Btrfs subvolume '@samsung_backup' does not exist in WD-1TB."
    echo "Nothing to restore."
    echo "Press ESC to exit..."
    wait_for_escape
    echo "Exiting..."
    exit 1
fi

if mountpoint -q "$HOME/.mount/SAMSUNG@STORAGE"; then
    echo "Verified that '~/.mount/SAMSUNG@STORAGE' is a successful mountpoint."
else
    echo "Nothing was mounted at '~/.mount/SAMSUNG@STORAGE'."
    echo "Nowhere to restore to."
    echo "Press ESC to exit..."
    wait_for_escape
    echo "Exiting..."
    exit 1
fi

echo "Rsync starting..."

if rsync -ah --info=progress2 ${TEMP_MOUNTPOINT}/@samsung_backup/ ${HOME}/.mount/SAMSUNG@STORAGE/; then
    echo "Successfully restored data from '@samsung_backup' to '~/.mount/SAMSUNG@STORAGE'."
else
    echo "Failed to restore data from '@samsung_backup' to '~/.mount/SAMSUNG@STORAGE'." >&2
    echo "Press ESC to exit..."
    wait_for_escape
    echo "Exiting..."
    exit 1
fi

if [[ -e "$HOME/.config/systemd/user/easy-effects.service" ]]; then
    echo "Detected 'easy-effects.service' for user ${USER}."
    echo "Enabling 'easy-effects.service' for user ${USER}..."
    if ! systemctl --user enable --now easy-effects.service; then
        echo "Failed to enable 'easy-effects.service' for user ${USER}." >&2
    else
        echo "Successfully enabled 'easy-effects.service' for user ${USER}."
    fi
fi

if [[ -e "/var/lib/dank-blue-build-personal/mounts-desktop-setup-done" ]]; then
    echo "Disabling '/usr/libexec/dank-blue-build-personal/mounts-setup'..."
    if ! sudo systemctl disable --now mounts-setup.service; then
        echo "Failed to disable 'mounts-setup.service'." >&2
    else
        echo "Successfully disabled 'mounts-setup.service'."
    fi
fi

echo "Updating XDG user directories..."
if xdg-user-dirs-update; then
    echo "Successfully updated XDG user directories."
else
    echo "Failed to update XDG user directories." >&2
fi

echo "Initializing Starship..."
if echo "eval \"\$(starship init bash)\"" >> ~/.bashrc; then
    echo "Successfully initialized Starship in '~/.bashrc'."
else
    echo "Failed to initialize Starship in '~/.bashrc'." >&2
fi

echo "Adding Fastfetch to '~/.bashrc'..."
if echo "fastfetch" >> ~/.bashrc; then
    echo "Successfully added Fastfetch to '~/.bashrc'."
else
    echo "Failed to add Fastfetch to '~/.bashrc'." >&2
fi

echo "Setup completed successfully."
touch "$STAMP_PATH/desktop-setup-done"

echo "Locking desktop-setup.sh to prevent accidental re-runs..."
if mv $HOME/.config/autostart/desktop-setup.desktop $HOME/.config/autostart/desktop-setup.desktop.lock; then
    echo "Successfully locked desktop-setup.sh."
else
    echo "Failed to lock desktop-setup.sh." >&2
fi

echo "Press ESC to exit..."
wait_for_escape
exit 0