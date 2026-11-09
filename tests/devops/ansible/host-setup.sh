#!/bin/sh
# Entry point of the test host for tests/check.sh devops: a clean debian:13 with sshd, a
# non-root user with password sudo (like the Proxmox host), python3 for Ansible, and the
# kubeconfig the playbook checks for. /fixture holds the SSH public key and kubeconfig.
set -eu
export LC_ALL=C
apt-get update -qq
apt-get install -y -qq --no-install-recommends openssh-server sudo python3 >/dev/null
useradd -m -s /bin/bash joakimia
echo 'joakimia:testpass' | chpasswd
usermod -aG sudo joakimia
install -d -m 700 -o joakimia -g joakimia /home/joakimia/.ssh /home/joakimia/.kube
install -m 600 -o joakimia -g joakimia /fixture/id_ed25519.pub /home/joakimia/.ssh/authorized_keys
install -m 600 -o joakimia -g joakimia /fixture/kubeconfig.yaml /home/joakimia/.kube/config
mkdir -p /run/sshd
exec /usr/sbin/sshd -D -e
