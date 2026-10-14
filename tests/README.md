# Tests

`check.sh` runs the repository's static checks. CI ([`.github/workflows/ci.yml`](../.github/workflows/ci.yml)) runs the same script, so run it locally before pushing:

```sh
tests/check.sh            # everything
tests/check.sh charts     # or one group: scripts | seeds | charts | cases | format | usage
```

| Group | What it checks |
|---|---|
| `scripts` | `bash -n`, `shellcheck -S warning`, and `export LC_ALL=C` (English output) on every non-empty `*.sh` |
| `seeds` | each `cloud-init.yaml` parses, starts with `#cloud-config`, and every `runcmd` script block passes `dash -n` |
| `charts` | all JSON parses, and every chart in every `deploy-set.json` has an executable `scripts/install.sh` and passes `helm lint` and `helm template` with the profile overlay |
| `cases` | each `charts/<chart>/pass-*.yaml` overlay renders and contains its `# expect:` lines; each `fail-*.yaml` fails with its `# expect:` text; the shared `_helpers.tpl` is identical in every chart |
| `format` | the [`.editorconfig`](../.editorconfig) basics on files in Git: final newline, no tabs, no trailing whitespace outside Markdown |
| `usage` | entry-point scripts exit 2 with usage when run without arguments |

The checks touch no VM or cluster and need no secrets. Locally you need `jq`, `helm`, `dash` (included in macOS), and `ruby` or `python3` with PyYAML. Install `shellcheck` too (`brew install shellcheck`); without it, that part is skipped locally, while CI requires it.

## Chart cases

Add a case with every chart rule or feature. Example `charts/pgbouncer/fail-duplicate-env.yaml`:

```yaml
# expect: DB_USER is set twice
env:
  DB_USER: plain
```
