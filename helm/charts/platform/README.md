# Platform chart

This chart defines the homelab namespace layout and the first network isolation rules. It creates only namespaces with `enabled: true` in `values.yaml`.

`values.yaml` contains the chart defaults. Helm validates overrides against `values.schema.json`, and the templates also fail with a clear message if required fields are missing. Namespace names must be valid Kubernetes namespace names; `enabled` must be an explicit boolean for each namespace.

Enabled for the current learning setup:

- `hlab-networking`: cluster entry points such as Traefik. It uses the `privileged` Pod Security profile so host ports 80/443 can be bound; keep this namespace limited to trusted networking workloads.
- `hlab-frontend-apps`: user-facing apps such as pgAdmin.
- `hlab-database`: PostgreSQL and PgBouncer.

The backend API, background worker, filestore, platform, tools, and observability namespaces are named in the values file but disabled. They will not be created until enabled. The namespace key `tools` maps to `hlab-tools` (one hyphen).

NetworkPolicies apply to the enabled namespaces: networking denies unsolicited pod ingress and permits HTTP/HTTPS to Traefik; frontend and database deny ingress and egress by default, allow DNS to the cluster DNS pods, and permit the planned Traefik → frontend apps → PgBouncer → PostgreSQL paths. The frontend ingress rule permits traffic only from the Traefik pods, so it also covers the homepage. Workload charts must use the pod labels and ports configured in `values.yaml`. Policies only take effect when the cluster CNI enforces Kubernetes NetworkPolicy; MicroK8s Calico does.

Install from the repository root:

```sh
helm upgrade --install platform ./helm/charts/platform --namespace default
```

The chart does not install or configure a DNS server for the Mac. Kubernetes CoreDNS resolves service names inside the cluster; Mac-side DNS for `pgadmin.homelab.com` is a separate concern.
