# Tests

`check.sh` runs the repository's static checks. CI ([`.github/workflows/ci.yml`](../.github/workflows/ci.yml)) runs the same script, so run it locally before pushing:

```sh
tests/check.sh            # everything except the Docker groups (CI runs those too)
tests/check.sh charts     # or one group: scripts | seeds | charts | cases | format | terraform | ansible | provisioning | usage | schema | devops | nodes
```

| Group | What it checks |
|---|---|
| `scripts` | `bash -n`, `shellcheck -S warning`, and `export LC_ALL=C` (English output) on every non-empty `*.sh` |
| `seeds` | each `cloud-init.yaml` parses, starts with `#cloud-config`, and every `runcmd` script block passes `dash -n` |
| `charts` | all JSON parses; every chart folder has a `README.md`; every chart in every `deploy-set.json` has an executable `scripts/install.sh`, the release `namespace` its script uses, and passes `helm lint` and `helm template` with the profile overlay; with Argo CD in a profile, its HTTPS chart repositories are registered there |
| `cases` | each `helm/charts/<chart>/pass-*.yaml` overlay renders and contains its `# expect:` lines; each `fail-*.yaml` fails with its `# expect:` text; the shared `_helpers.tpl` is identical in every chart |
| `format` | the [`.editorconfig`](../.editorconfig) basics on files in Git: final newline, no tabs, no trailing whitespace outside Markdown; relative Markdown links resolve; every action in `.github/workflows` exists at its ref |
| `terraform` | `tofu fmt`, `tofu init`/`validate` in each root (folder with `.terraform.lock.hcl`), and `tofu test` with a mocked Cloudflare provider for `tests/infratructure/cloudflare/*.tftest.hcl` |
| `ansible` | `ansible-playbook --syntax-check` and `ansible-lint` (production profile) on `devops/ansible` |
| `provisioning` | each `infratructure/.../debian13/{pass,fail}-*.txt` case runs the provisioning `install.sh` with stub `ssh` and `scp` and checks the output, the remote calls, and the seed it copies or writes to an ISO |
| `usage` | entry-point scripts exit 2 with usage when run without arguments |
| `schema` | Docker: `cloud-init schema` from Debian 13 (the nodes' version) on the user-data `install.sh` renders from each seed; about 30 seconds |
| `devops` | Docker: the `devops/ansible` playbook against a clean `debian:13` host over SSH (`tests/devops/ansible`), twice; the second run must change nothing, and Helm, kubectl, and OpenTofu must run; about 30 seconds |
| `nodes` | Docker: the functions `install.sh` runs on the nodes (join, `/etc/hosts`, RKE2 token files), in `debian:13` with a `microk8s` stub |

The default run skips `schema`, `devops`, and `nodes` unless `CI=true`; run them by name when you change seeds, the Ansible playbook, or the node functions. CI runs everything on each pull request, on pushes to `main`, and weekly, which catches drift in upstream packages, images, and charts.

The case folders mirror the code they test: `helm/charts/<chart>/` for `helm/charts/<chart>`, `infratructure/on-premises/virtual-machine/debian13/` for the provisioning `install.sh`, `infratructure/cloudflare/` for the OpenTofu module, and `devops/ansible/` for the playbook's test host.

The checks touch no VM or cluster and need no secrets. Locally you need `jq`, `helm`, `dash` (included in macOS), and `ruby` or `python3` with PyYAML. Install `shellcheck` too (`brew install shellcheck`), and OpenTofu, ansible-core, and ansible-lint with `mise install` (`mise.toml`); without them, those parts are skipped locally, while CI requires them. The `--iso` cases need `hdiutil` (macOS) or `xorriso`, and are skipped locally without them.

## Chart cases

Add a case with every chart rule or feature. Example `helm/charts/pgbouncer/fail-duplicate-env.yaml`:

```yaml
# expect: DB_USER is set twice
env:
  DB_USER: plain
```

## Provisioning cases

Add a case with every `install.sh` mode, rule, or failure message. Example `infratructure/on-premises/virtual-machine/debian13/pass-join-microk8s-worker.txt`:

```text
# args: --join debian@cp0 microk8s worker-node debian@wk0
# reply: debian@cp0 cat '.homelab-join- => 192.0.2.10:25000/K10secret/hash
# expect-order: apply_seed
# expect-order: join_node 'homelab-cp0' '192.0.2.10'
# expect-not: K10secret
```

- `# args:` are split on spaces. The script runs from an empty directory with a test SSH key.
- `# reply: <text> => <output>`: the ssh stub prints `<output>` for the first call whose `<target> <command>` contains `<text>`. Without a reply, `hostname` prints `homelab-<host>`, and the node's address is `192.0.2.10` for hosts starting with `cp` and `192.0.2.20` otherwise.
- The checked output is the script's output, then `== calls` (each ssh and scp call; `sudo bash -c` scripts decoded), `== scp <file>`, and `== iso <file>`. ssh stdin is not included, so `# expect-not:` on a token proves that it never appears in an argument or in the output.
- `# expect:` must appear, `# expect-not:` must not, `# expect-order:` lines must appear in that order, and `# exit:` sets the exit status. `pass-*` must exit 0 and `fail-*` must not.
