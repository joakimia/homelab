# Traefik chart

Installs Traefik as a Deployment in `hlab-networking`, with `replicaCount: 1` by default. It watches standard Kubernetes `Ingress` resources and publishes HTTP/HTTPS on host ports 80 and 443 on the selected node. This keeps the browser URL on ordinary ports. Each replica needs a separate node because the host ports can only be bound once per node; scale it only when additional nodes are available.

Install the platform chart first so the namespace and its network policies exist:

```sh
helm upgrade --install platform ./helm/charts/platform --namespace default
helm upgrade --install traefik ./helm/charts/traefik \
  --namespace hlab-networking
```

An app chart should create an `Ingress` with `spec.ingressClassName: traefik`. For example, pgAdmin's DNS name must resolve to a node IP, and its Service must be reachable on the configured target port. The chart does not install DNS, publish the Traefik dashboard, or configure TLS certificates. Port 80 works for the initial local HTTP check; add certificate management before relying on HTTPS.

Override `replicaCount`, `namespace`, image version, ports, resources, node selector, and tolerations in a cluster-specific values file. Host ports 80 and 443 must be available on each node where Traefik is scheduled.
