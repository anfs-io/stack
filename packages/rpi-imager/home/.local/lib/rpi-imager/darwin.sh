# rpi-imager — macOS disk operations
#
# Sourced by ~/.local/bin/rpi-imager on Darwin. Every platform lib must provide the
# same contract; nothing outside these libs may call diskutil, lsblk or friends.
#
#   disk_list                  tab-separated: device, size, bus, removable, model
#   disk_size_bytes DEVICE     size in bytes, or "" if unknown
#   disk_model DEVICE          human model string
#   disk_validate DEVICE       die unless DEVICE is a safe whole-disk target
#   disk_unmount DEVICE        unmount every partition, keeping the device node
#   disk_mount_boot DEVICE     echo the mounted boot partition, or return 1
#   disk_raw DEVICE            device to hand to dd
#   disk_partition DEVICE N    Nth partition's device path
#   disk_part_uuid PARTDEV     PARTUUID of a partition, or ""
#   disk_eject DEVICE          flush and release
#   boot_hint                  extra advice when writing to the boot partition fails

disk_info_field() {
  diskutil info -plist "$1" 2>/dev/null | plutil -extract "$2" raw -o - - 2>/dev/null || true
}

disk_size_bytes() { disk_info_field "$1" TotalSize; }
disk_model()      { disk_info_field "$1" MediaName; }

disk_list() {
  local d size
  while IFS= read -r d; do
    [[ -n "$d" ]] || continue
    size="$(disk_size_bytes "/dev/$d")"
    printf '/dev/%s\t%s\t%s\t%s\t%s\n' \
      "$d" \
      "$(human_bytes "${size:-0}")" \
      "$(disk_info_field "/dev/$d" BusProtocol)" \
      "$(disk_info_field "/dev/$d" Ejectable)" \
      "$(disk_info_field "/dev/$d" MediaName)"
  done < <(diskutil list -plist external physical 2>/dev/null \
           | plutil -convert json -o - - 2>/dev/null \
           | yq -p json -r '.WholeDisks // [] | .[]' 2>/dev/null || true)
}

disk_validate() {
  local device="$1" internal ejectable whole size max

  [[ "$device" =~ ^/dev/disk[0-9]+$ ]] \
    || die "%s is not a whole macOS disk — pass /dev/diskN, not a partition like /dev/disk4s1\n  (list candidates with: rpi-imager disks)" "$device"

  whole="$(disk_info_field "$device" WholeDisk)"
  [[ -n "$whole" ]] || die "%s not found (list disks with: rpi-imager disks)" "$device"
  [[ "$whole" == true ]] || die "%s is not a whole disk" "$device"

  internal="$(disk_info_field "$device" Internal)"
  ejectable="$(disk_info_field "$device" Ejectable)"
  if [[ "$internal" == true || "$ejectable" == false ]]; then
    die "%s is an internal or non-ejectable disk — refusing to touch it" "$device"
  fi

  max="$(image_field max_size_gb)"
  size="$(disk_size_bytes "$device")"
  if [[ -n "$max" && -n "$size" ]] && (( size > max * 1000000000 )); then
    die "%s is %s, larger than image.yml's max_size_gb (%s GB) — refusing" \
        "$device" "$(human_bytes "$size")" "$max"
  fi
}

# unmountDisk, not eject: eject removes the device node and the write then fails
disk_unmount() {
  diskutil unmountDisk "$1" >/dev/null 2>&1 \
    || sudo diskutil unmountDisk "$1" >/dev/null 2>&1 \
    || die "could not unmount %s — close anything using it and retry" "$1"
}

disk_mount_boot() {
  local device="$1" mount
  # The ext4 root will not mount on macOS; that is expected, so ignore the exit status
  diskutil mountDisk "$device" >/dev/null 2>&1 || true
  for mount in /Volumes/bootfs /Volumes/boot; do
    [[ -d "$mount" && -f "$mount/cmdline.txt" ]] && { printf '%s\n' "$mount"; return 0; }
  done
  mount="$(mount | awk -v d="${device#/dev/}s" 'index($1, "/dev/" d) == 1 && /msdos/ { print $3; exit }')"
  [[ -n "$mount" && -f "$mount/cmdline.txt" ]] && { printf '%s\n' "$mount"; return 0; }
  return 1
}

# /dev/rdiskN is the raw character device: unbuffered and far faster than /dev/diskN
disk_raw() { printf '%s\n' "${1/\/dev\/disk//dev/rdisk}"; }

disk_partition() { printf '%ss%s\n' "$1" "$2"; }

disk_part_uuid() {
  diskutil info -plist "$1" 2>/dev/null \
    | plutil -extract VolumeUUID raw -o - - 2>/dev/null || true
}

disk_eject() {
  sync
  diskutil eject "$1" >/dev/null 2>&1 \
    || sudo diskutil eject "$1" >/dev/null 2>&1 \
    || warn "could not eject %s — unmount it before unplugging" "$1"
}

# macOS gates removable media separately from Full Disk Access
boot_hint() {
  printf '\n  macOS gates removable media separately from Full Disk Access:\n    System Settings > Privacy & Security > Files and Folders\n    > your terminal > enable "Removable Volumes"'
}
