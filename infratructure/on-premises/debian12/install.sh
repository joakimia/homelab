#!/usr/bin/env bash
# Provisions a Debian 12 machine with a NoCloud cloud-init seed: a Kubernetes node from
# <distro>/<role>/cloud-init.yaml (distro: microk8s or rke2), or the jumpbox from
# jumpbox/cloud-init.yaml (no role).
#
#   ./install.sh <microk8s|rke2> <control-plane-node|worker-node> debian@<vm-ip> [hostname]
#   ./install.sh jumpbox debian@<vm-ip> [hostname]
#       Default, from the Mac over SSH: renders the seed, copies it to the VM, installs
#       cloud-init there if needed, and runs it. Asks for the SSH password once (if no key is
#       set up yet) and the sudo password.
#       For the jumpbox it then copies the bundle (this provisioning folder and helm/) to
#       ~/homelab-bundle, so nodes can be provisioned and deployed from there.
#   ./install.sh --iso <microk8s|rke2> <control-plane-node|worker-node> [hostname] [output.iso]
#   ./install.sh --iso jumpbox [hostname] [output.iso]
#       Only writes a seed ISO (volume label cidata) to attach as a CD/DVD drive in UTM, for a
#       VM that already has cloud-init installed. Default output: ./<hostname>-seed.iso in the
#       directory you run it from.
#
# The seed authorizes this machine's SSH public key for the debian user, so SSH works without a
# password once cloud-init has run. Set HOMELAB_SSH_PUBLIC_KEY=/path/to/key.pub to choose a key.
set -Eeuo pipefail
export LC_ALL=C  # English messages from bash and tools, whatever the local language

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../../.." && pwd)"

usage() {
  echo "Usage: $0 <microk8s|rke2> <control-plane-node|worker-node> debian@<vm-ip> [hostname]" >&2
  echo "       $0 jumpbox debian@<vm-ip> [hostname]" >&2
  echo "       $0 --iso <microk8s|rke2> <control-plane-node|worker-node> [hostname] [output.iso]" >&2
  echo "       $0 --iso jumpbox [hostname] [output.iso]" >&2
  exit 2
}

# Sets seed (distro/role) and default_hostname, or exits for an unknown distro or role.
check_seed() {
  local prefix
  if [[ "$1" == jumpbox ]]; then
    seed=jumpbox
    default_hostname=homelab-jumpbox
    return
  fi
  case "$1" in
    microk8s) prefix=homelab ;;
    rke2) prefix=homelab-rke2 ;;
    *) echo "Unknown distro: $1" >&2; usage ;;
  esac
  case "$2" in
    control-plane-node) default_hostname=$prefix-cp0 ;;
    worker-node) default_hostname=$prefix-wk0 ;;
    *) echo "Unknown node role: $2" >&2; usage ;;
  esac
  seed=$1/$2
}

check_hostname() {
  [[ "$1" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] || { echo "Invalid hostname: $1" >&2; exit 2; }
}

# Writes user-data (cloud-init.yaml plus this machine's SSH key) and meta-data into a directory.
render_seed() {
  local seed=$1 hostname=$2 out_dir=$3
  local source_file="$script_dir/$seed/cloud-init.yaml" public_key_file=${HOMELAB_SSH_PUBLIC_KEY:-} public_key='' candidate
  [[ -f "$source_file" ]] || { echo "Cloud-init config not found: $source_file" >&2; exit 1; }

  if [[ -z "$public_key_file" ]]; then
    for candidate in ~/.ssh/id_ed25519.pub ~/.ssh/id_ecdsa.pub ~/.ssh/id_rsa.pub; do
      if [[ -f "$candidate" ]]; then
        public_key_file=$candidate
        break
      fi
    done
  fi

  if [[ -n "$public_key_file" ]]; then
    [[ -f "$public_key_file" ]] || { echo "Public key not found: $public_key_file" >&2; exit 1; }
    # Keep only "<type> <base64>" so the YAML line needs no quoting.
    public_key=$(awk 'NR == 1 {print $1, $2}' "$public_key_file")
    if [[ ! "$public_key" =~ ^(ssh-[a-z0-9-]+|ecdsa-sha2-nistp[0-9]+|sk-[a-z0-9@.-]+)\ [A-Za-z0-9+/]+=*$ ]]; then
      echo "Not an OpenSSH public key: $public_key_file" >&2
      exit 1
    fi
    awk -v key="$public_key" '
      { print }
      $0 == "  - name: debian" { print "    ssh_authorized_keys:"; print "      - " key; added++ }
      END { exit(added == 1 ? 0 : 1) }
    ' "$source_file" > "$out_dir/user-data" || {
      echo "Could not add the SSH key: expected one '  - name: debian' entry in $source_file" >&2
      exit 1
    }
    echo "Authorizing SSH key for debian: $public_key_file"
  else
    echo "No SSH public key found; the VM will only accept password logins. Create one with ssh-keygen -t ed25519." >&2
    cp "$source_file" "$out_dir/user-data"
  fi

  cat > "$out_dir/meta-data" <<EOF
instance-id: $hostname
local-hostname: $hostname
EOF
}

# Runs on the VM through sudo: installs cloud-init, stages the NoCloud seed, and runs all stages.
apply_seed() {
  set -Eeuo pipefail
  local seed_upload=$1 seed_dir=/var/lib/cloud/seed/nocloud
  # shellcheck disable=SC2064 # expand now: seed_upload is local and gone when the trap fires
  trap "rm -rf '$seed_upload'" EXIT

  if ! command -v cloud-init >/dev/null; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y cloud-init
  fi
  # The Debian installer already configured networking. Without this, cloud-init rewrites
  # /etc/network/interfaces on the running system, the original dhclient stops, and the DHCP
  # lease silently expires (UTM: after an hour), leaving the machine without IPv4.
  install -d -m 0755 /etc/cloud/cloud.cfg.d
  printf 'network: {config: disabled}\n' > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg

  install -d -m 0755 "$seed_dir"
  install -m 0644 "$seed_upload/user-data" "$seed_upload/meta-data" "$seed_dir/"

  echo "Running cloud-init with the NoCloud seed..."
  cloud-init clean --logs
  cloud-init init --local
  cloud-init init
  cloud-init modules --mode=config
  cloud-init modules --mode=final
  cloud-init status --long
  echo "Cloud-init finished. Log out and back in so group and PATH changes apply."
}

install_over_ssh() {
  # seed_dir, control_dir, target, and ssh_opts stay global: the EXIT trap uses them.
  local seed=$1 hostname=$3 remote_dir remote_command remote_home
  target=$2
  command -v ssh >/dev/null || { echo "ssh is required" >&2; exit 1; }
  command -v scp >/dev/null || { echo "scp is required" >&2; exit 1; }

  seed_dir=$(mktemp -d)
  # Short path: SSH control sockets are limited to about 104 bytes, and macOS $TMPDIR is long.
  control_dir=$(mktemp -d /tmp/homelab-ssh.XXXXXX)
  remote_dir=".homelab-cloud-init-$hostname-$$"
  # Share one SSH connection so the password (if no key is set up yet) is asked only once.
  ssh_opts=(-o ControlMaster=auto -o "ControlPath=$control_dir/%C" -o ControlPersist=120)
  trap 'ssh "${ssh_opts[@]}" -O exit "$target" 2>/dev/null || true; rm -rf "$seed_dir" "$control_dir"' EXIT

  render_seed "$seed" "$hostname" "$seed_dir"
  echo "Copying the cloud-init seed for $hostname ($seed) to $target..."
  remote_home=$(ssh "${ssh_opts[@]}" "$target" 'printf %s "$HOME"')
  remote_dir="$remote_home/$remote_dir"
  ssh "${ssh_opts[@]}" "$target" "mkdir -p '$remote_dir'"
  scp "${ssh_opts[@]}" -q "$seed_dir/user-data" "$seed_dir/meta-data" "$target:$remote_dir/"

  # Send apply_seed's definition with the call, so the VM needs nothing from this repository.
  remote_command="$(declare -f apply_seed); apply_seed '$remote_dir'"
  echo "Installing cloud-init and running the seed on $target. Enter the sudo password if prompted."
  ssh "${ssh_opts[@]}" -t "$target" "sudo bash -c $(printf '%q' "$remote_command")"

  if [[ "$seed" == jumpbox ]]; then
    copy_bundle "$remote_home/homelab-bundle"
  fi
}

# Copies this provisioning folder and helm/ to the jumpbox, replacing the previous bundle.
# Uses target and ssh_opts from install_over_ssh.
copy_bundle() {
  local bundle_dir=$1 archive tar_opts=()
  archive="$seed_dir/bundle.tar.gz"
  # macOS bsdtar stores Finder/provenance metadata that GNU tar on Debian warns about.
  if tar --version 2>/dev/null | grep -q bsdtar; then
    tar_opts=(--no-mac-metadata --no-xattrs)
  fi
  COPYFILE_DISABLE=1 tar ${tar_opts[@]+"${tar_opts[@]}"} --exclude '*.iso' --exclude .local -czf "$archive" -C "$repo_root" \
    "${script_dir#"$repo_root"/}" helm
  echo "Copying the bundle to $target:$bundle_dir..."
  ssh "${ssh_opts[@]}" "$target" "rm -rf '$bundle_dir' && mkdir -p '$bundle_dir'"
  scp "${ssh_opts[@]}" -q "$archive" "$target:$bundle_dir/bundle.tar.gz"
  ssh "${ssh_opts[@]}" "$target" "tar -xzf '$bundle_dir/bundle.tar.gz' -C '$bundle_dir' && rm '$bundle_dir/bundle.tar.gz'"
  echo "Bundle ready. On the jumpbox: cd ~/homelab-bundle/${script_dir#"$repo_root"/} && ./install.sh <distro> <role> debian@<node-ip>"
}

build_iso() {
  # build_dir stays global: the EXIT trap uses it.
  local seed=$1 hostname=$2 output=$3 iso_tool='' candidate
  for candidate in hdiutil xorriso genisoimage mkisofs; do
    if command -v "$candidate" >/dev/null; then
      iso_tool=$candidate
      break
    fi
  done
  [[ -n "$iso_tool" ]] || { echo "An ISO tool is required: hdiutil (macOS) or xorriso/genisoimage (Linux)." >&2; exit 1; }

  output="$(cd -- "$(dirname -- "$output")" && pwd)/$(basename -- "$output")"
  build_dir=$(mktemp -d)
  trap 'rm -rf "$build_dir"' EXIT
  render_seed "$seed" "$hostname" "$build_dir"

  # NoCloud finds the seed by the volume label "cidata".
  case "$iso_tool" in
    hdiutil) hdiutil makehybrid -ov -o "$output" -iso -joliet -default-volume-name cidata "$build_dir" >/dev/null ;;
    xorriso) xorriso -as mkisofs -quiet -o "$output" -V cidata -J -r "$build_dir" ;;
    *) "$iso_tool" -quiet -o "$output" -V cidata -J -r "$build_dir" ;;
  esac
  echo "Created $output for $seed ($hostname). Attach it as a CD/DVD drive to the UTM VM and boot."
}

iso=false
if [[ "${1:-}" == --iso ]]; then
  iso=true
  shift
fi
[[ $# -ge 1 ]] || usage
if [[ "$1" == jumpbox ]]; then
  check_seed jumpbox
  shift
else
  [[ $# -ge 2 ]] || usage
  check_seed "$1" "$2"
  shift 2
fi

if [[ "$iso" == true ]]; then
  [[ $# -le 2 ]] || usage
  hostname=${1:-$default_hostname}
  check_hostname "$hostname"
  build_iso "$seed" "$hostname" "${2:-$PWD/$hostname-seed.iso}"
else
  [[ $# -ge 1 && $# -le 2 ]] || usage
  [[ "$1" =~ ^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+$ ]] || { echo "Use an SSH target like debian@192.168.64.12." >&2; exit 2; }
  hostname=${2:-$default_hostname}
  check_hostname "$hostname"
  install_over_ssh "$seed" "$1" "$hostname"
fi
