# Helm deployments

This directory contains reusable charts and environment-specific deployment profiles.

- `charts/` contains one chart per application or platform component. Some directories are scaffolds and are not ready to install.
- `deployment/` groups the charts used by a particular cluster or environment.

For the current UTM development target, see [`deployment/dev/mac-utm-k3s-cluster/`](deployment/dev/mac-utm-k3s-cluster/README.md). Use the profile's install script to create its namespaces, secrets, and Helm releases; review its README before running it.
