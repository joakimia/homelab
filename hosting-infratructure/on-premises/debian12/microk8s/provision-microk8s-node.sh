#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <control-plane-node|worker-node> <hostname>" >&2
  exit 2
fi

role=$1
hostname=$2

case "$role" in
  control-plane-node|worker-node) ;;
  *) echo "Unknown node role: $role" >&2; exit 2 ;;
esac

if [[ ! "$hostname" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]]; then
  echo "Invalid hostname: $hostname" >&2
  exit 2
fi

if [[ $EUID -ne 0 ]]; then
  echo "Run this script through sudo on the Debian VM." >&2
  exit 1
fi

provision_user=${SUDO_USER:-}

if [[ -z "$provision_user" || "$provision_user" == root ]] || ! getent passwd "$provision_user" >/dev/null; then
  echo "Connect over SSH as a regular user, then run this script with sudo." >&2
  exit 1
fi

user_home=$(getent passwd "$provision_user" | cut -d: -f6)

if [[ -z "$user_home" || ! -d "$user_home" ]]; then
  echo "Could not find the home directory for $provision_user." >&2
  exit 1
fi

echo "Setting hostname to $hostname and installing MicroK8s, Helm, kubectl, and k9s..."
hostnamectl set-hostname "$hostname"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl snapd
systemctl enable --now snapd.socket
ln -sfn /var/lib/snapd/snap /snap
snap wait system seed.loaded

install_snap() {
  local name=$1
  shift
  if ! snap list "$name" >/dev/null 2>&1; then
    snap install "$name" "$@"
  fi
}

install_snap microk8s --classic
install_snap helm --classic
install_snap kubectl --classic
if snap list k9s >/dev/null 2>&1; then
  snap remove k9s
fi

case "$(dpkg --print-architecture)" in
  amd64) k9s_asset=k9s_Linux_amd64.tar.gz ;;
  arm64) k9s_asset=k9s_Linux_arm64.tar.gz ;;
  *) echo "Unsupported architecture for k9s: $(dpkg --print-architecture)" >&2; exit 1 ;;
esac
k9s_tmp=$(mktemp -d)
trap 'rm -rf "$k9s_tmp"' EXIT
k9s_release_url=https://github.com/derailed/k9s/releases/latest/download
curl -fsSL --retry 3 "$k9s_release_url/checksums.sha256" -o "$k9s_tmp/checksums.sha256"
curl -fsSL --retry 3 "$k9s_release_url/$k9s_asset" -o "$k9s_tmp/$k9s_asset"
k9s_checksum=$(awk -v asset="$k9s_asset" '$2 == asset || $2 == "*" asset {print $1; exit}' "$k9s_tmp/checksums.sha256")
if [[ ! "$k9s_checksum" =~ ^[[:xdigit:]]{64}$ ]]; then
  echo "Could not find a SHA-256 checksum for $k9s_asset." >&2
  exit 1
fi
printf '%s  %s\n' "$k9s_checksum" "$k9s_tmp/$k9s_asset" | sha256sum --check --status
tar -xzf "$k9s_tmp/$k9s_asset" -C "$k9s_tmp" k9s
install -m 0755 "$k9s_tmp/k9s" /usr/local/bin/k9s
rm -rf "$k9s_tmp"
trap - EXIT

usermod -aG microk8s "$provision_user"
/snap/bin/microk8s status --wait-ready
/snap/bin/microk8s enable hostpath-storage

install -d -o "$provision_user" -g "$provision_user" -m 0700 "$user_home/.kube"
/snap/bin/microk8s config > "$user_home/.kube/config"
chown "$provision_user:$provision_user" "$user_home/.kube/config"
chmod 0600 "$user_home/.kube/config"

sudo -u "$provision_user" env HOME="$user_home" /usr/local/bin/k9s version

echo "Provisioning complete for $hostname ($role). Log out and back in before using kubectl, helm, or k9s."
