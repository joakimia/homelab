# Repository instructions

## Project context

This is a personal hobby and learning project. The goal is to build practical understanding of Linux, cloud-init, Kubernetes, Helm, and infrastructure automation. Do not describe the setup as production-ready.

The first goal is a clean Debian 12 VM in UTM, provisioned from the Mac with a NoCloud cloud-init seed, running MicroK8s with Helm, kubectl, and k9s, and the development Helm profile deployed and verified. RKE2 on physical hardware, with a jumpbox that provisions the nodes and hosts a local registry, is the later goal; its seeds are work in progress.

The current UTM cluster runs MicroK8s and uses the profile `helm/deployment/dev/mac-utm-microk8s-cluster`. Confirm the active Kubernetes context and the actual cluster before changing anything.

UTM's `192.168.64.x` network and its address/DNS notes apply only to that VM. Do not carry them into the RKE2-on-hardware setup; define addressing, DNS, and routing for the home LAN there.

The current stack is platform namespaces and policies, Traefik, PostgreSQL, PgBouncer, pgAdmin, and a Caddy homepage. Ingress is HTTP only, on host port 8080. An Ingress hostname does not create DNS: clients need a DNS record or hosts entry, and HTTPS needs an intentional TLS setup and trusted certificate.

## Working rules

- Preserve the user's existing changes. Do not revert, overwrite, or delete unrelated work. The user often edits files while you work; build on their version.
- Do not commit or push unless the user asks.
- Do not add passwords, tokens, kubeconfig files, or other secrets to Git. Create secrets during installation or keep them in local, ignored files (`.local/`).
- Distinguish implemented charts, seeds, and profiles from scaffolds and work in progress.
- Keep documentation short and practical. Mark incomplete content as work in progress and update it as the setup is verified.
- Run `tests/check.sh` after changes; CI (`.github/workflows/ci.yml`) runs the same script. It covers `bash -n`, shellcheck, cloud-init YAML and `dash -n` on `runcmd` blocks, `helm lint`/`helm template` with profile overlays, and usage exits. Keep CI workflow files minimal: they install tools and call repository scripts. New checks go into `check.sh`. Do not run tests or provision/deploy against a VM or cluster unless the user asks; report exactly what was run.
- For cloud-init changes, follow the real flow from a clean Debian install. Do not assume packages or tools are already present.
- Other profiles are separate targets and must not be deployed automatically.
- Keep the Mac's default kubeconfig intact. `deploy.sh` writes a separate, ignored `.local/homelab-kubeconfig`; use it explicitly for checks and k9s.
- Treat provisioning and deployment as learning workflows: explain what a command changes and verify the result at the relevant layer.
- **English only in the repository:** docs, comments, script output and error messages, commit messages, and skill files. Every script sets `export LC_ALL=C` right after `set -euo pipefail`, so messages from bash and tools are English whatever the local language (the Mac is set to Norwegian). The user often writes to you in Norwegian; you may answer in their language, but anything written into the repo is English.

## Conventions

- **Few entry points.** Provisioning has one script, `infratructure/on-premises/debian12/install.sh`. Each Helm profile has `install.sh` (over SSH: bundle, copy, deploy on the node) and `deploy.sh` (remote from the Mac, or `--local`). Put new logic into these instead of adding helper scripts; follow the `shell-scripts` skill for structure (usage header, `usage()`, validators, one function per step, dispatch at the bottom).
- **Portable host scripts.** Scripts run on the Mac must also work on Linux: bash 3.2 compatible (guard empty arrays under `set -u`), detect tools instead of assuming them (for example `hdiutil` or `xorriso`, BSD or GNU tar), and no `sed -i ''`.
- **Outputs go where the script is run.** Generated files such as seed ISOs and `.local/homelab-kubeconfig` are written under the caller's current directory unless a path is given. `*.iso` and `.local/` are ignored by Git.
- **Pinned versions.** Seeds pin MicroK8s and kubectl to a snap track, and Helm, k9s, kubectl, and the RKE2 installer to exact releases with a SHA-256 per architecture. Update the version tables in the READMEs with them.
- **Unprivileged ports.** No port 80: Traefik uses 8080/8443, apps listen on 8080, and pgAdmin on 5050. Do not add `NET_BIND_SERVICE` for ports; add it only when the image binary carries it as a file capability (the caddy image does, see the homepage chart).
- **SSH access.** The seed authorizes the provisioning machine's public key, so only the first `install.sh` run asks for a password. The jumpbox has its own key for the nodes it provisions.
- **Charts and profiles.** Follow the `kubernetes-helm` skill: one template file per resource, `required` checks with `$_` and full value paths, all defaults in the chart's `values.yaml` and `values.schema.json`, Secrets created by the chart's `scripts/install.sh`, and profile order and flags in `deploy-set.json`.
- **Helm 4 on the Mac.** Use `--rollback-on-failure` (Helm 3's `--atomic`); the profile `deploy.sh` translates it for Helm 3.

## Repository layout

- `infratructure/on-premises/debian12/` — shared `install.sh` and cloud-init seeds: `microk8s/` (current), `rke2/` and `jumpbox/` (work in progress).
- `helm/charts/` — every chart the homelab can use; some are scaffolds.
- `helm/deployment/<env>/<cluster>/` — cluster profiles that choose and deploy charts.
- `docs/` — architecture notes, user guides, and runbooks.
- `tests/` — `check.sh` (static checks, also run by CI) and placeholder folders for later VM/cluster tests.
- `.claude/skills/` — `debian-cloud-init` (provisioning), `kubernetes-helm` (charts, profiles, troubleshooting), and `shell-scripts` (script structure and portability).
