---
name: shell-scripts
description: Create, change, review, or consolidate shell scripts in the homelab repository (install.sh, deploy.sh, chart scripts/install.sh, cloud-init runcmd blocks). Enforces the repo's structure for usage headers, argument parsing, functions, cleanup traps, macOS/Linux portability, and keeping the number of scripts small.
---

# Homelab shell scripts

Use this skill whenever you add, change, or review a `.sh` file or a cloud-init `runcmd` script block. The existing scripts are the reference. Read the closest one before you write anything:

| Kind | Reference | Runs on |
|---|---|---|
| Multi-mode entry point | `infratructure/on-premises/debian12/install.sh` | Mac or Linux host, remote code over SSH |
| Profile deploy loop | `helm/deployment/dev/local-microk8s-cluster-dev/deploy.sh` | Mac, or the node with `--local` |
| Bundle and run over SSH | `helm/deployment/dev/local-microk8s-cluster-dev/install.sh` | Mac |
| Single chart installer | `helm/charts/postgres/scripts/install.sh` | wherever `helm`/`kubectl` work |
| Seed script block | `runcmd` blocks in `*/cloud-init.yaml` | the node, as POSIX `sh` (dash) |

## Keep the number of scripts small

- **Add a mode, not a script.** A folder has at most the entry points that already exist there:
  - provisioning: one `debian12/install.sh`
  - Helm profile: `install.sh` and `deploy.sh`
  - chart: `scripts/install.sh`
- A new capability becomes a function plus a flag or mode in the existing script, for example `--iso`, `--kubeconfig`, `--local`, or the `jumpbox` mode.
- Small one-off helpers become a README line, as the k9s command did, not a new file.
- Do not create wrapper scripts that only `exec` another script.
- Code that must run on another machine lives as a function in the same file. Send it with `$(declare -f fn); fn args` through `ssh ... "sudo bash -c $(printf '%q' "$cmd")"`, so the remote side needs nothing from the repository (see `apply_seed`).
- Before adding a script, check whether an existing one can take the mode. If a new entry point is really needed, say why and ask the user.

## File layout, top to bottom

1. `#!/usr/bin/env bash`
2. **Header comment.** One or two lines on what the script does, then each mode as an indented usage line with a short explanation. Mark the default mode, say where it runs (Mac, node, remote over SSH), and note anything not implemented yet (for example "a local mode can be added later").
3. `set -euo pipefail` (or `set -Eeuo pipefail` when functions rely on ERR traps), then `export LC_ALL=C  # English messages from bash and tools, whatever the local language`. Everything a script prints is English.
4. **Paths.** Resolve them from the script, never from the caller's directory: `script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"`, plus `repo_root`, `profile_dir`, `charts_dir` as needed.
5. **`usage()`.** It prints every mode to stderr and exits with code 2.
6. **Small `check_*` validators.** Examples:
   - an SSH target: `^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+$`
   - a hostname: `^[a-zA-Z0-9][a-zA-Z0-9.-]*$`
   - a chart name: `^[a-z0-9-]+$`
   - a known role or distro, through `case`
7. **One function per step or mode**, named by what it does: `render_seed`, `build_iso`, `install_over_ssh`, `copy_bundle`, `fetch_kubeconfig`, `deploy_releases`. Each function starts with a one-line comment on what it does and anything it depends on, such as globals it shares with a trap.
8. **Dispatch at the bottom.** A `case "${1:-}"` or a short `if` parses the mode and argument count, calls `usage` on anything unexpected, validates arguments, and then calls the functions. Keep parsing out of the functions.

## Behaviour

- **Fail early and clearly.**
  - Check required tools with `command -v x >/dev/null || { echo "x is required" >&2; exit 1; }`.
  - Check prerequisites, such as a namespace or Secret existing, with a message that says what to do next.
  - Exit codes: 2 for usage errors, 1 for failures.
- **Say what is happening.** Print a short line before each slow or remote step ("Copying ... to $target...") and print where outputs went. Errors go to stderr.
- **Idempotent reruns.** Create Secrets or keys only if missing, use `helm upgrade --install`, and replace bundle directories instead of extracting on top of old files.
- **Outputs go to the caller's directory.** Write generated files (ISOs, `.local/<cluster>.kubeconfig`) under `$PWD` unless a path is passed. Use `mktemp` for anything temporary. Make sure generated credentials land in ignored paths (`.local/`, `*.iso`).
- **Cleanup.** Use `trap '...' EXIT` for temp files and SSH control sockets.
  - Variables a trap reads must still exist when it fires: keep them global (with a comment saying so), or expand them when the trap is set (`trap "rm -rf '$dir'" EXIT`, with `# shellcheck disable=SC2064 # expand now: ...`). Do not use `local` for them.
- **SSH.** Share one connection so a password is asked only once:
  - `ssh_opts=(-o ControlMaster=auto -o "ControlPath=$control_dir/%C" -o ControlPersist=120)`
  - Use `control_dir=$(mktemp -d /tmp/homelab-ssh.XXXXXX)`. Socket paths must stay under about 104 bytes, and macOS's `$TMPDIR` is too long.
  - Close the connection in the trap.
  - Never put passwords or tokens in arguments; let `ssh` and `sudo` prompt.
- **Pass-through arguments.** Chart installers end with `helm upgrade --install <release> "$chart_dir" --namespace <ns> "$@"`. Keep that contract.

## Portability (macOS and Linux)

- **bash 3.2 (macOS).** No `mapfile`, associative arrays, `${var,,}`, or `|&`. Expand arrays that may be empty under `set -u` as `${arr[@]+"${arr[@]}"}`. Build arrays from command output with a `while IFS= read -r` loop.
- **BSD vs GNU tools.**
  - No `sed -i` in host-side scripts (BSD and GNU differ); use a temporary file or another tool. On the node (Debian, GNU), `sed -i` is fine.
  - Use `mktemp "${TMPDIR:-/tmp}/name.XXXXXX"` and `mktemp -d`; avoid `mktemp -t`.
  - Detect bsdtar before using its flags (`--no-mac-metadata --no-xattrs`), and set `COPYFILE_DISABLE=1`.
  - Pick an available tool when there are alternatives, such as `hdiutil`, `xorriso`, or `genisoimage`.
- **Cloud-init `runcmd` blocks run under `/bin/sh` (dash on Debian).** POSIX only: no arrays, `[[ ]]`, `${var/x/y}`, or `local`. Start with `set -e`, and pin versions and SHA-256 values as variables at the top of the block.

## Checks before you finish

- Update `tests/check.sh` with the script: a new entry point goes into `check_usage`, a new check into its own group.
- Run `tests/check.sh` (the same checks as CI): `bash -n`, `shellcheck -S warning`, seed checks, chart lint, and usage exits. Fix shellcheck warnings rather than disabling them; when a disable is intentional, add the reason on the same line. Write empty locals as `x=''`, not `x=`.
- `dash -n` on extracted `runcmd` blocks, for example in a `debian:12` container.
- Run the usage paths: no arguments and wrong arguments must print usage and exit 2.
- Exercise local modes that need no cluster or VM (for example `--iso`), and clean up what they create.
- Keep scripts executable (`chmod +x`); scaffold scripts stay empty and are not wired into anything.
- Update the README that documents the script's modes in the same change.
- Do not run modes that change a VM or cluster unless the user asks.
