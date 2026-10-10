# Repository instructions

## Project context

This is a personal hobby and learning project. The goal is to build practical understanding of Linux, cloud-init, Kubernetes, Helm, and infrastructure automation. Do not describe the setup as production-ready.

The first goal is to install a clean Debian 12 VM in UTM, provide a NoCloud cloud-init seed from the Mac, install MicroK8s and Helm, kubectl, and k9s, then verify the Helm deployment. Running RKE2 on physical hardware is a later goal.

The current UTM environment is MicroK8s even though its profile directory is named `helm/deployment/dev/mac-utm-k3s-cluster`. Confirm the active Kubernetes context and actual cluster before making changes; do not infer the distribution from the directory name.

UTM's `192.168.64.x` network and its local address/DNS settings are specific to that VM profile. Do not carry them into the future RKE2-on-hardware profile; define addressing, DNS, and routing for the physical home LAN there.

The current learning stack is platform namespaces and policies, Traefik, PostgreSQL, PgBouncer, pgAdmin, and a Caddy homepage. The local ingress routes are HTTP-only. A hostname in an Ingress does not create DNS: clients need a DNS record or a local hosts entry, and HTTPS also needs an intentional TLS configuration and trusted certificate.

## Working rules

- Preserve the user's existing changes. Do not revert, overwrite, or delete unrelated work.
- Do not commit or push unless the user asks.
- Do not add passwords, tokens, kubeconfig files, or other secrets to Git. Create secrets during installation or use local, untracked files.
- Distinguish implemented charts and deployment profiles from scaffolds.
- Keep documentation short and practical. Mark incomplete content as work in progress and update it as the setup is verified.
- Do not add or run tests unless the user asks for testing or verification. When asked, report exactly what was run and the result.
- For cloud-init or installer changes, check syntax and follow the real UTM flow from a clean Debian install. Do not assume packages or tools are already present on the VM.
- Use `helm/deployment/dev/mac-utm-k3s-cluster/` for the current UTM development profile. Other profiles are separate targets and must not be deployed automatically.
- Keep the Mac's default kubeconfig intact. The UTM connection helper stores a separate, ignored kubeconfig under `.local/`; use that explicit config for local checks and k9s.
- Treat provisioning and deployment as learning workflows: explain what a command changes, verify the result at the relevant layer, and keep secrets out of values files and Git.

## Repository layout

- `infratructure/on-premises/debian12/microk8s/` — Debian and MicroK8s provisioning.
- `helm/charts/` — individual application and platform charts.
- `helm/deployment/` — profiles that group charts for an environment.
- `docs/` — architecture notes, user guides, and runbooks.
