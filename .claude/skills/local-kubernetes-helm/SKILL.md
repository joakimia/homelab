---
name: local-kubernetes-helm
description: Deploy, inspect, or troubleshoot the homelab Helm charts on the Debian UTM MicroK8s development cluster, including ingress, DNS, storage, and app secrets.
---

# Local MicroK8s and Helm workflow

Use this skill for the UTM development stack in `helm/deployment/dev/mac-utm-k3s-cluster/`.

## Before changing a cluster

1. Read the profile README and `AGENTS.md`.
2. Inspect `kubectl config current-context`, cluster nodes, and relevant Helm releases before applying changes. The profile directory's `k3s` name is historical; the current UTM guest runs MicroK8s.
3. For commands from the Mac, use the profile's `.local/homelab-kubeconfig` explicitly. Do not rewrite or clean the user's global kubeconfig, and do not deploy this profile to Docker Desktop, AKS, or another context.
4. Use the profile installer or its Helm commands in dependency order. Keep secrets created by the installer in Kubernetes Secrets; never commit generated credentials or place them in Helm values.

## Troubleshooting layers

Check the request path one layer at a time:

1. DNS/hosts resolution maps the requested hostname to the VM address; Kubernetes Ingress does not create that mapping.
2. Traefik listens on the configured node ports. Check the Ingress class, host, path, backend Service, and ready endpoints.
3. Confirm the URL scheme matches the configured entrypoint. The current UTM profile serves the named routes over HTTP; an HTTPS request needs TLS configuration and a certificate trusted by the client.
4. Check the application pod and logs only after the request has reached the correct Ingress route.

For a temporary HTTP check without changing DNS, follow the profile README's `curl --resolve` examples. A Traefik 404 usually means no route matched the Host/path/entrypoint; it does not by itself prove the application is down. A browser DNS NXDOMAIN means resolution failed before Kubernetes was reached.

## Storage and app relationships

- The UTM profile's `homelab-pvc-storage` class maps to MicroK8s hostpath storage. Check the actual PVC and StorageClass before assuming a chart default changed an existing claim.
- PostgreSQL is the database backend, PgBouncer is its connection pooler, and pgAdmin is a browser client. Verify each service and namespace rather than treating the stack as a single release.
- Keep replicas at one for the current single-node learning environment unless the user explicitly chooses a different topology.
