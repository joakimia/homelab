#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <seed-iso> <hostname>" >&2
  exit 2
fi

seed_iso=$1
hostname=$2

if [[ $EUID -ne 0 ]]; then
  echo "Run this script through sudo on the Debian VM." >&2
  exit 1
fi

if [[ ! -f "$seed_iso" ]]; then
  echo "Seed ISO not found: $seed_iso" >&2
  exit 1
fi

if [[ ! "$hostname" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]]; then
  echo "Invalid hostname: $hostname" >&2
  exit 2
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y cloud-init

mount_dir=$(mktemp -d)
seed_dir=/var/lib/cloud/seed/nocloud

cleanup() {
  mountpoint -q "$mount_dir" && umount "$mount_dir" || true
  rm -rf "$mount_dir" "$seed_iso"
}
trap cleanup EXIT

mount -o loop,ro "$seed_iso" "$mount_dir"
install -d -m 0755 "$seed_dir"

for seed_file in user-data meta-data vendor-data; do
  if [[ -f "$mount_dir/$seed_file" ]]; then
    install -m 0644 "$mount_dir/$seed_file" "$seed_dir/$seed_file"
  fi
done

if [[ ! -s "$seed_dir/user-data" || ! -s "$seed_dir/meta-data" ]]; then
  echo "Seed ISO must contain non-empty user-data and meta-data files." >&2
  exit 1
fi

echo "Starting cloud-init with the NoCloud seed for $hostname..."
cloud-init clean --logs
cloud-init init --local
cloud-init init
cloud-init modules --mode=config
cloud-init modules --mode=final
cloud-init status --long
echo "Cloud-init run complete. Reboot the VM if the provisioning config changed its hostname or networking."
