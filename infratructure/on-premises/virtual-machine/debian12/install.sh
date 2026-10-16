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
#       A control-plane-node provisioned this way starts a cluster of its own; an RKE2
#       worker-node stays stopped until it joins one.
#   ./install.sh --join debian@<cluster-ip> <microk8s|rke2> <control-plane-node|worker-node> debian@<vm-ip> [hostname]
#   ./install.sh --join-only debian@<cluster-ip> <microk8s|rke2> <control-plane-node|worker-node> debian@<vm-ip>
#       --join provisions as above and joins the node to the cluster of <cluster-ip> (a control
#       plane); --join-only joins a node provisioned earlier. A worker-node joins as a worker, a
#       control-plane-node as another control plane. Waits until the node is Ready. Asks for the
#       sudo password on both nodes.
#       MicroK8s: adds both nodes to each other's /etc/hosts, creates a one-time join token on the
#       control plane (valid 10 minutes), and runs microk8s join after provisioning.
#       RKE2 (work in progress): writes the server URL and the cluster's token to
#       /etc/rancher/rke2/config.yaml.d/50-join.yaml before provisioning, so the seed starts the
#       service already joined. An RKE2 control plane cannot use --join-only: it has started a
#       cluster of its own, so provision it again with --join.
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
repo_root="$(cd -- "$script_dir/../../../.." && pwd)"

usage() {
  echo "Usage: $0 <microk8s|rke2> <control-plane-node|worker-node> debian@<vm-ip> [hostname]" >&2
  echo "       $0 jumpbox debian@<vm-ip> [hostname]" >&2
  echo "       $0 --join debian@<cluster-ip> <microk8s|rke2> <control-plane-node|worker-node> debian@<vm-ip> [hostname]" >&2
  echo "       $0 --join-only debian@<cluster-ip> <microk8s|rke2> <control-plane-node|worker-node> debian@<vm-ip>" >&2
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

check_ssh_target() {
  [[ "$1" =~ ^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+$ ]] || { echo "Use an SSH target like debian@192.168.5.57, not: $1" >&2; exit 2; }
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
    # Wipe the stale pre-baked mirror cache from the clean base image
    apt-get clean
    rm -rf /var/lib/apt/lists/*

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

# Sets up SSH to target (and join_target, if set) with one shared connection per host, so a
# password (if no key is set up yet) is asked only once. seed_dir, control_dir, target,
# join_target, and ssh_opts stay global: the EXIT trap and the later steps use them.
start_ssh() {
  target=$1
  join_target=$2
  command -v ssh >/dev/null || { echo "ssh is required" >&2; exit 1; }
  command -v scp >/dev/null || { echo "scp is required" >&2; exit 1; }
  seed_dir=$(mktemp -d)
  # Short path: SSH control sockets are limited to about 104 bytes, and macOS $TMPDIR is long.
  control_dir=$(mktemp -d /tmp/homelab-ssh.XXXXXX)
  ssh_opts=(-o ControlMaster=auto -o "ControlPath=$control_dir/%C" -o ControlPersist=120)
  trap 'ssh "${ssh_opts[@]}" -O exit "$target" 2>/dev/null || true
    [[ -z "$join_target" ]] || ssh "${ssh_opts[@]}" -O exit "$join_target" 2>/dev/null || true
    rm -rf "$seed_dir" "$control_dir"' EXIT
}

# Renders the seed, copies it to target, and runs it there. Uses the globals from start_ssh.
install_over_ssh() {
  local seed=$1 hostname=$2 remote_dir=".homelab-cloud-init-$2-$$" remote_command remote_home
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

# Runs on a node through sudo: points name at ip in /etc/hosts, replacing an entry written here
# before. MicroK8s refuses a join when the worker's hostname does not resolve to its IP.
set_hosts_entry() {
  local ip=$1 name=$2 hosts
  hosts=$(awk -v n="$name" '!($2 == n && $3 == "#" && $4 == "homelab-join")' /etc/hosts)
  printf '%s\n%s %s # homelab-join\n' "$hosts" "$ip" "$name" > /etc/hosts
}

# Runs on the control plane through sudo: adds the worker to /etc/hosts and, unless the worker is
# already a node, writes a join URL with a one-time token to url_file, readable only by owner.
prepare_join() {
  set -Eeuo pipefail
  local worker_name=$1 worker_ip=$2 cp_ip=$3 url_file=$4 owner=$5 url
  set_hosts_entry "$worker_ip" "$worker_name"
  install -m 0600 -o "$owner" /dev/null "$url_file"
  /snap/bin/microk8s status --wait-ready --timeout 120 >/dev/null
  if /snap/bin/microk8s kubectl get node "$worker_name" >/dev/null 2>&1; then
    echo "$worker_name is already a node of this cluster; skipping the join."
    return
  fi
  # Lines look like "microk8s join <ip>:25000/<token>/<hash>", one per control-plane address.
  url=$(/snap/bin/microk8s add-node --token-ttl 600 --format short |
    awk -v prefix="$cp_ip:25000/" 'index($3, prefix) == 1 {print $3; exit}')
  [[ -n "$url" ]] || { echo "microk8s add-node printed no join URL for $cp_ip" >&2; exit 1; }
  printf '%s\n' "$url" > "$url_file"
}

# Runs on the joining node through sudo: adds the control plane to /etc/hosts and joins with the
# URL in url_file (empty when the node is already in the cluster), then removes url_file. A new
# control plane gets the cluster's certificates, so the user's kubeconfig is written again.
join_node() {
  set -Eeuo pipefail
  local cp_name=$1 cp_ip=$2 url_file=$3 role=$4 user=$5 home
  # shellcheck disable=SC2064 # expand now: url_file is local and gone when the trap fires
  trap "rm -f '$url_file'" EXIT
  set_hosts_entry "$cp_ip" "$cp_name"
  [[ -s "$url_file" ]] || return 0
  if [[ "$role" == worker-node ]]; then
    echo "Joining the cluster as a worker (this restarts MicroK8s here)..."
    /snap/bin/microk8s join "$(cat "$url_file")" --worker
  else
    echo "Joining the cluster as a control plane (this restarts MicroK8s here)..."
    /snap/bin/microk8s join "$(cat "$url_file")"
    /snap/bin/microk8s status --wait-ready --timeout 300 >/dev/null
    home=$(getent passwd "$user" | cut -d: -f6)
    /snap/bin/microk8s config | sed "s#server: https://.*:16443#server: https://127.0.0.1:16443#" > "$home/.kube/config"
    echo "Rewrote $home/.kube/config with the cluster's credentials."
  fi
}

# Prints the IPv4 source address of a node's default route: the address other nodes see.
node_ip() {
  ssh "${ssh_opts[@]}" "$1" 'ip -4 route get 1.1.1.1' |
    awk '{for (i = 1; i < NF; i++) if ($i == "src") {print $(i + 1); exit}}'
}

# Fails unless target reaches port on ip, before any token is created.
check_reachable() {
  local ip=$1 port=$2
  ssh "${ssh_opts[@]}" "$target" "timeout 5 bash -c '</dev/tcp/$ip/$port'" 2>/dev/null || {
    echo "$target cannot reach $ip:$port. The nodes must reach each other; in UTM, VMs on one network must not be isolated from each other." >&2
    exit 1
  }
}

# Joins target to join_target's MicroK8s cluster in the given role. Uses the globals from
# start_ssh. The token goes through files, never command arguments.
join_microk8s() {
  local role=$1 node_name cp_name node_ip cp_ip url url_file=".homelab-join-$$" remote_command
  echo "Joining $target to the cluster of $join_target as $role..."
  node_name=$(ssh "${ssh_opts[@]}" "$target" hostname | tr '[:upper:]' '[:lower:]')
  cp_name=$(ssh "${ssh_opts[@]}" "$join_target" hostname | tr '[:upper:]' '[:lower:]')
  node_ip=$(node_ip "$target")
  cp_ip=$(node_ip "$join_target")
  [[ -n "$node_ip" && -n "$cp_ip" ]] || { echo "Could not find the IPv4 addresses of $target and $join_target" >&2; exit 1; }
  [[ "$node_name" != "$cp_name" ]] || { echo "Both machines are named $node_name; node names must be unique." >&2; exit 1; }
  echo "Node $node_name ($node_ip), control plane $cp_name ($cp_ip)."

  # ==================== ADD THESE TWO LINES HERE ====================
  echo "Opening port 25000 on both cluster hosts..."
  ssh "${ssh_opts[@]}" -t "$join_target" "sudo ufw allow 25000/tcp && sudo ufw reload" 2>/dev/null || true
  ssh "${ssh_opts[@]}" -t "$target" "sudo ufw allow 25000/tcp && sudo ufw reload" 2>/dev/null || true
  # ==================================================================

  check_reachable "$cp_ip" 25000

  remote_command="$(declare -f set_hosts_entry prepare_join); prepare_join '$node_name' '$node_ip' '$cp_ip' '$url_file' '${join_target%@*}'"

  echo "Creating a join token on $join_target. Enter its sudo password if prompted."
  ssh "${ssh_opts[@]}" -t "$join_target" "sudo bash -c $(printf '%q' "$remote_command")"
  url=$(ssh "${ssh_opts[@]}" "$join_target" "cat '$url_file' && rm -f '$url_file'")

  ssh "${ssh_opts[@]}" "$target" "umask 077 && cat > '$url_file'" <<< "$url"
  remote_command="$(declare -f set_hosts_entry join_node); join_node '$cp_name' '$cp_ip' '$url_file' '$role' '${target%@*}'"
  echo "Joining on $target. Enter its sudo password if prompted."
  ssh "${ssh_opts[@]}" -t "$target" "sudo bash -c $(printf '%q' "$remote_command")"
}

# Runs on an RKE2 server through sudo: copies the join token to token_file, readable only by
# owner. Workers get the agent token, which cannot join servers when the cluster sets one.
export_rke2_token() {
  set -Eeuo pipefail
  local role=$1 token_file=$2 owner=$3 dir=/var/lib/rancher/rke2/server source=node-token
  if [[ "$role" == worker-node && -s "$dir/agent-token" ]]; then
    source=agent-token
  fi
  [[ -s "$dir/$source" ]] || { echo "$dir/$source not found: is this an RKE2 server?" >&2; exit 1; }
  install -m 0600 -o "$owner" "$dir/$source" "$token_file"
}

# Runs on the joining node through sudo: writes the server URL and the token from token_file to
# the drop-in that rke2-server or rke2-agent reads when it starts. Removes token_file.
write_rke2_join() {
  set -Eeuo pipefail
  local server=$1 token_file=$2 dir=/etc/rancher/rke2/config.yaml.d
  # shellcheck disable=SC2064 # expand now: token_file is local and gone when the trap fires
  trap "rm -f '$token_file'" EXIT
  [[ -s "$token_file" ]] || { echo "No join token received." >&2; exit 1; }
  install -d -m 0755 /etc/rancher/rke2 "$dir"
  umask 077
  printf 'server: %s\ntoken: %s\n' "$server" "$(cat "$token_file")" > "$dir/50-join.yaml"
  echo "Wrote $dir/50-join.yaml (server $server)."
}

# Before provisioning (or for --join-only), gives target the join settings for join_target's
# RKE2 cluster. node_name is the name the node will have. Uses the globals from start_ssh.
stage_rke2_join() {
  local role=$1 node_name=$2 cp_name cp_ip token token_file=".homelab-join-$$" remote_command
  cp_name=$(ssh "${ssh_opts[@]}" "$join_target" hostname | tr '[:upper:]' '[:lower:]')
  cp_ip=$(node_ip "$join_target")
  [[ -n "$cp_ip" ]] || { echo "Could not find the IPv4 address of $join_target" >&2; exit 1; }
  [[ "$node_name" != "$cp_name" ]] || { echo "Both machines are named $node_name; node names must be unique." >&2; exit 1; }
  echo "Joining $target as $node_name ($role) to the RKE2 cluster of $cp_name ($cp_ip)."
  check_reachable "$cp_ip" 9345

  remote_command="$(declare -f export_rke2_token); export_rke2_token '$role' '$token_file' '${join_target%@*}'"
  echo "Reading the join token on $join_target. Enter its sudo password if prompted."
  ssh "${ssh_opts[@]}" -t "$join_target" "sudo bash -c $(printf '%q' "$remote_command")"
  token=$(ssh "${ssh_opts[@]}" "$join_target" "cat '$token_file' && rm -f '$token_file'")

  ssh "${ssh_opts[@]}" "$target" "umask 077 && cat > '$token_file'" <<< "$token"
  remote_command="$(declare -f write_rke2_join); write_rke2_join 'https://$cp_ip:9345' '$token_file'"
  echo "Writing the join settings on $target. Enter its sudo password if prompted."
  ssh "${ssh_opts[@]}" -t "$target" "sudo bash -c $(printf '%q' "$remote_command")"
}

# Starts rke2-agent on a worker provisioned earlier, after stage_rke2_join. Blocks until the
# agent has registered. Uses the globals from start_ssh.
start_rke2_agent() {
  echo "Starting rke2-agent on $target (this can take a few minutes)..."
  ssh "${ssh_opts[@]}" -t "$target" "sudo systemctl enable rke2-agent.service && sudo systemctl restart rke2-agent.service"
}

# Waits on join_target until target's node is Ready, running kubectl_command there.
wait_for_node() {
  local kubectl_command=$1 node_name
  node_name=$(ssh "${ssh_opts[@]}" "$target" hostname | tr '[:upper:]' '[:lower:]')
  echo "Waiting for node $node_name to be Ready..."
  ssh "${ssh_opts[@]}" "$join_target" "for i in \$(seq 60); do $kubectl_command get node '$node_name' >/dev/null 2>&1 && break; sleep 5; done
    $kubectl_command wait --for=condition=Ready 'node/$node_name' --timeout=300s && $kubectl_command get nodes -o wide"
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
join_target=''
join_only=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso) iso=true; shift ;;
    --join | --join-only)
      [[ $# -ge 2 && -z "$join_target" ]] || usage
      [[ "$1" == --join ]] || join_only=true
      check_ssh_target "$2"
      join_target=$2
      shift 2 ;;
    *) break ;;
  esac
done
[[ $# -ge 1 ]] || usage
if [[ "$1" == jumpbox ]]; then
  check_seed jumpbox
  shift
else
  [[ $# -ge 2 ]] || usage
  check_seed "$1" "$2"
  shift 2
fi

if [[ -n "$join_target" && ( "$iso" == true || "$seed" == jumpbox ) ]]; then
  echo "--join and --join-only work only for Kubernetes nodes over SSH." >&2
  exit 2
fi
if [[ "$join_only" == true && "$seed" == rke2/control-plane-node ]]; then
  echo "An RKE2 control plane has started a cluster of its own; provision it again with --join." >&2
  exit 2
fi

if [[ "$iso" == true ]]; then
  [[ $# -le 2 ]] || usage
  hostname=${1:-$default_hostname}
  check_hostname "$hostname"
  build_iso "$seed" "$hostname" "${2:-$PWD/$hostname-seed.iso}"
else
  [[ $# -ge 1 && $# -le 2 ]] || usage
  [[ "$join_only" == false || $# -eq 1 ]] || usage
  check_ssh_target "$1"
  hostname=${2:-$default_hostname}
  check_hostname "$hostname"
  start_ssh "$1" "$join_target"
  if [[ -n "$join_target" && "$seed" == rke2/* ]]; then
    if [[ "$join_only" == true ]]; then
      hostname=$(ssh "${ssh_opts[@]}" "$target" hostname)
    fi
    stage_rke2_join "${seed#*/}" "$(printf %s "$hostname" | tr '[:upper:]' '[:lower:]')"
  fi
  if [[ "$join_only" == false ]]; then
    install_over_ssh "$seed" "$hostname"
  fi
  case "$join_target:$seed" in
    :*) ;;
    *:microk8s/*)
      join_microk8s "${seed#*/}"
      wait_for_node '/snap/bin/microk8s kubectl' ;;
    *:rke2/*)
      if [[ "$join_only" == true ]]; then
        start_rke2_agent
      fi
      wait_for_node kubectl ;;
  esac
fi
