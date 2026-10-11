# rpi-imager — Linux disk operations (Raspberry Pi OS / Debian)
#
# Sourced by ~/.local/bin/rpi-imager on Linux. See darwin.sh for the contract every
# platform lib implements.
#
# The safety model differs from macOS in an important way. On macOS a target is
# rejected when it is Internal or non-Ejectable. That test is useless here: a USB SSD
# normally reports RM=0 (non-removable), so it would reject the very disk you mean to
# write. Instead this lib refuses any disk that backs a mounted filesystem the running
# system depends on — /, /boot and /boot/firmware — which is the failure that actually
# destroys a machine.

# The whole disk backing mount point $1, e.g. / -> /dev/mmcblk0
disk_of_mount() {
  local src pk
  src="$(findmnt -no SOURCE --target "$1" 2>/dev/null | head -1)" || return 1
  [[ -n "$src" && "$src" == /dev/* ]] || return 1
  pk="$(lsblk -no PKNAME "$src" 2>/dev/null | head -1 | tr -d ' ')"
  if [[ -n "$pk" ]]; then
    printf '/dev/%s\n' "$pk"
  else
    printf '%s\n' "$src"          # already a whole disk
  fi
}

disk_size_bytes() { lsblk -dnbo SIZE "$1" 2>/dev/null | tr -d ' '; }
disk_model()      { lsblk -dno MODEL "$1" 2>/dev/null | sed 's/ *$//'; }

disk_list() {
  local name size tran rm model protected="" m d
  for m in / /boot /boot/firmware; do
    d="$(disk_of_mount "$m")" && protected="$protected $d"
  done

  while read -r name size tran rm model; do
    case "$name" in /dev/loop*|/dev/ram*|/dev/zram*|/dev/sr*) continue ;; esac
    # Mark rather than hide the system disk, so it is obvious which one not to pick
    case " $protected " in
      *" $name "*) model="${model:-} [SYSTEM DISK — will be refused]" ;;
    esac
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$name" "$size" "${tran:-?}" \
      "$([[ "$rm" == "1" ]] && echo true || echo false)" \
      "${model:-?}"
  done < <(lsblk -dpno NAME,SIZE,TRAN,RM,MODEL 2>/dev/null)
}

disk_validate() {
  local device="$1" mnt sysdisk max size

  [[ -b "$device" ]] \
    || die "%s is not a block device (list candidates with: rpi-imager disks)" "$device"
  [[ "$(lsblk -dno TYPE "$device" 2>/dev/null | tr -d ' ')" == "disk" ]] \
    || die "%s is a partition — pass the whole disk (e.g. /dev/sda, not /dev/sda1)" "$device"

  # The guard that matters: never write over the running system
  for mnt in / /boot /boot/firmware; do
    sysdisk="$(disk_of_mount "$mnt")" || continue
    [[ "$sysdisk" == "$device" ]] && die \
      "%s holds %s of the RUNNING system — refusing.\n  Writing it would destroy the machine you are typing on.\n  Pick the target with: rpi-imager disks" \
      "$device" "$mnt"
  done

  max="$(image_field max_size_gb)"
  size="$(disk_size_bytes "$device")"
  if [[ -n "$max" && -n "$size" ]] && (( size > max * 1000000000 )); then
    die "%s is %s, larger than image.yml's max_size_gb (%s GB) — refusing" \
        "$device" "$(human_bytes "$size")" "$max"
  fi
}

disk_unmount() {
  local device="$1" part
  while read -r part; do
    [[ -n "$part" ]] || continue
    sudo umount "$part" 2>/dev/null \
      || die "could not unmount %s — close anything using it and retry" "$part"
  done < <(lsblk -lnpo NAME,MOUNTPOINT "$device" 2>/dev/null | awk '$2 != "" { print $1 }')
}

# mmcblk0 / nvme0n1 take a "p" before the partition number; sda does not
disk_partition() {
  case "$1" in
    *[0-9]) printf '%sp%s\n' "$1" "$2" ;;
    *)      printf '%s%s\n'  "$1" "$2" ;;
  esac
}

disk_mount_boot() {
  local device="$1" part mnt
  part="$(disk_partition "$device" 1)"

  if [[ ! -b "$part" ]]; then
    sudo partprobe "$device" >/dev/null 2>&1 || true
    udevadm settle >/dev/null 2>&1 || true
  fi
  [[ -b "$part" ]] || return 1

  # Already mounted somewhere? use that
  mnt="$(findmnt -no TARGET "$part" 2>/dev/null | head -1)"
  [[ -n "$mnt" ]] && { printf '%s\n' "$mnt"; return 0; }

  mnt="$RPI_IMAGER_MOUNT"
  mkdir -p "$mnt"
  # uid/gid so the copied files are owned by the user, not root
  sudo mount -o "uid=$(id -u),gid=$(id -g)" "$part" "$mnt" 2>/dev/null || return 1
  RPI_IMAGER_MOUNTED_BY_US="$mnt"
  printf '%s\n' "$mnt"
}

# Linux writes the block device directly; there is no raw character device
disk_raw() { printf '%s\n' "$1"; }

disk_part_uuid() { lsblk -dno PARTUUID "$1" 2>/dev/null | tr -d ' '; }

# Deliberately does NOT power the device down. On a Pi that is about to reboot into
# this very disk, a udisks power-off would leave it electrically absent at boot.
disk_eject() {
  sync
  if [[ -n "${RPI_IMAGER_MOUNTED_BY_US:-}" ]]; then
    sudo umount "$RPI_IMAGER_MOUNTED_BY_US" 2>/dev/null \
      || warn "could not unmount %s" "$RPI_IMAGER_MOUNTED_BY_US"
    RPI_IMAGER_MOUNTED_BY_US=""
  fi
  sync
}

boot_hint() { printf ''; }
