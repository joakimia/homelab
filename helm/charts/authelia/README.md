# Authelia chart

Runs [Authelia](https://www.authelia.com/) in `hlab-platform`: a login portal at `https://auth.homelab.com:8443/` with users in a file and data in SQLite on a PVC. Password reset links go to `/data/notification.txt` (no e-mail).

Apps opt in with `ingress.auth.enabled`: Traefik's `authelia@file` middleware asks Authelia before each request and passes `Remote-User`, `Remote-Email`, and `Remote-Groups` to the app.

## Install

Installed by the MicroK8s profile after `cert-issuers` (for TLS). Alone: `./scripts/install.sh --wait`.

## Secrets

`scripts/install.sh` creates the `authelia` Secret on first install: generated JWT, session, and storage keys, and `users_database.yml` with one admin. Name, email, and password come from `AUTHELIA_ADMIN_USER`, `AUTHELIA_ADMIN_EMAIL`, `AUTHELIA_ADMIN_PASSWORD`, a prompt, or the defaults (`admin`, `admin@homelab.com`, generated password, printed once). The password is stored as a SHA-512 crypt hash.

The Secret is mounted as files at `/secrets`; Authelia reads the keys through its `*_FILE` variables. To add users, edit `users_database.yml` in the Secret (hash with `authelia crypto hash generate`) and restart the pod.

## Values

| Value | Default | Purpose |
|---|---|---|
| `host` | `auth.homelab.com` | Portal hostname. |
| `service.port` / `containerPort` | `9091` / `9091` | Authelia's default port. |
| `config.session.domain` | `homelab.com` | Cookie domain; protected hosts must be below it. |
| `config.session.autheliaUrl` / `defaultRedirectionUrl` | `https://auth.homelab.com:8443` / homepage | Portal URL and where to go after login. |
| `config.accessControl.defaultPolicy` / `rules` | `deny` / `*.homelab.com` one factor | Access rules (the list is replaced, not merged, by an overlay). |
| `storage.size` | `256Mi` | PVC for SQLite and notifications. |
| `defaultEnv` / `defaultSecrets.authelia` | see `values.yaml` | `*_FILE` paths and the mounted Secret. |
| `probes.*` | `httpGet /api/health` | Startup, readiness, and liveness probes. |

## Templates

`configmap.yaml` (`configuration.yml`), `deployment.yaml`, `service.yaml`, `ingress.yaml`, `persistentvolumeclaim.yaml`, `_helpers.tpl`.
