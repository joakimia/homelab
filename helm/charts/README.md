# Helm charts

The current UTM development install set is documented in [the dev cluster profile](../deployment/dev/mac-utm-k3s-cluster/README.md). It consists of `platform`, `traefik`, `postgres`, `pgbouncer`, `pgadmin`, and `homepage`.

Each selected chart has a `scripts/install.sh` wrapper. The profile's `install.sh` creates the required Kubernetes Secrets and installs all six releases in dependency order. Use `install-via-ssh.sh` from the Mac to copy the profile to the Debian VM and run the same installer there.

Charts outside this profile are not installed by the development script.
