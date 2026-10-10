# Repository instructions

## Project context

This is a personal hobby and learning project. The goal is to build practical understanding of Linux, cloud-init, Kubernetes, Helm, and infrastructure automation. Do not describe the setup as production-ready.

The first goal is to install a clean Debian 12 VM in UTM, provide a NoCloud cloud-init seed from the Mac, install MicroK8s and Helm, kubectl, and k9s, then verify the Helm deployment. Running RKE2 on physical hardware is a later goal.

## Working rules

- Preserve the user's existing changes. Do not revert, overwrite, or delete unrelated work.
- Do not commit or push unless the user asks.
- Do not add passwords, tokens, kubeconfig files, or other secrets to Git. Create secrets during installation or use local, untracked files.
- Distinguish implemented charts and deployment profiles from scaffolds.
- Keep documentation short and practical. Mark incomplete content as work in progress and update it as the setup is verified.
- Do not add or run tests unless the user asks for testing or verification. When asked, report exactly what was run and the result.
- For cloud-init or installer changes, check syntax and follow the real UTM flow from a clean Debian install. Do not assume packages or tools are already present on the VM.
- Use `helm/deployment/dev/mac-utm-k3s-cluster/` for the current UTM development profile. Other profiles are separate targets and must not be deployed automatically.

## Repository layout

- `hosting-infratructure/on-premises/debian12/microk8s/` — Debian and MicroK8s provisioning.
- `helm/charts/` — individual application and platform charts.
- `helm/deployment/` — profiles that group charts for an environment.
- `docs/` — architecture notes, user guides, and runbooks.
