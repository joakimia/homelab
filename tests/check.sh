#!/usr/bin/env bash
# Static checks for the homelab repository. CI (.github/workflows/ci.yml) runs exactly this
# script, so a local run reproduces CI. Nothing here touches a VM or cluster.
#
#   ./check.sh             Default: run every check below.
#   ./check.sh scripts     bash -n, shellcheck, and export LC_ALL=C on every non-empty *.sh file.
#   ./check.sh seeds       Parse each cloud-init.yaml, require #cloud-config, and run
#                          dash -n on every runcmd script block (cloud-init runs them with sh).
#   ./check.sh charts      helm lint and helm template for each chart in each deploy-set.json,
#                          with the profile's values overlay; JSON files must parse, and no
#                          "---" separator may be glued to the end of a line.
#                          Fetches chart dependencies (needs network).
#   ./check.sh cases       helm template with each tests/charts/<chart>/{pass,fail}-*.yaml overlay:
#                          pass-* must render and contain each "# expect:" text, fail-* must
#                          fail with it. Fetches chart dependencies (needs network).
#                          Shared _helpers.tpl files must be identical.
#   ./check.sh format      .editorconfig basics on files in Git: final newline, no tabs, and no
#                          trailing whitespace (Markdown excepted); relative Markdown links resolve.
#   ./check.sh usage       Entry-point scripts and the base chart installers exit 2 and print
#                          usage without arguments.
#
# Needs bash, jq, helm, dash, and ruby or python3 with PyYAML. shellcheck is optional
# locally (a notice is printed) and required when CI=true.
set -euo pipefail
export LC_ALL=C  # English messages from bash and tools, whatever the local language

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
failures=0

usage() {
  echo "Usage: $0 [scripts|seeds|charts|cases|format|usage]" >&2
  exit 2
}

require() {
  command -v "$1" >/dev/null || { echo "Required command not found: $1" >&2; exit 1; }
}

# Records a failed check without stopping, so one run reports every problem.
fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

# Lists repository files matching a name pattern, skipping .git and generated folders.
repo_files() {
  find "$repo_root" \( -name .git -o -name .local \) -prune -o -type f -name "$1" -print | sort
}

# Prints each string runcmd entry of a cloud-init file as NUL-separated records.
runcmd_blocks() {
  if command -v ruby >/dev/null; then
    ruby -ryaml -e 'd = YAML.load_file(ARGV[0]); (d["runcmd"] || []).each { |c| print c, "\0" if c.is_a?(String) }' "$1"
  else
    python3 -c 'import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
for c in d.get("runcmd") or []:
    if isinstance(c, str):
        sys.stdout.write(c + "\0")' "$1"
  fi
}

# Prints lines where a template trimmed the newline before a "---" document separator
# (for example "</html>---"): Helm then reads two resources as one and drops the first.
glued_separators() {
  grep -nE '[^[:space:]-]---[[:space:]]*$' || true
}

# Registers the HTTPS chart repositories a chart depends on, which helm dependency build needs
# (OCI repositories need nothing). The name is the host, for example charts-longhorn-io.
add_chart_repos() {
  local url
  while IFS= read -r url; do
    helm repo list 2>/dev/null | grep -q "$url" && continue
    helm repo add "$(printf '%s' "$url" | sed -E 's#^https://##; s#[^a-z0-9]+#-#g; s#-+$##')" "$url" >/dev/null \
      || fail "helm repo add $url"
  done < <(sed -nE 's#^[[:space:]]*repository:[[:space:]]*(https://[^[:space:]]+).*#\1#p' "$1/Chart.yaml")
}

check_scripts() {
  local file have_shellcheck=true
  echo "==> scripts"
  if ! command -v shellcheck >/dev/null; then
    [[ "${CI:-}" != true ]] || { echo "shellcheck is required in CI" >&2; exit 1; }
    have_shellcheck=false
    echo "Notice: shellcheck not installed; skipping it (brew install shellcheck to match CI)."
  fi
  while IFS= read -r file; do
    [[ -s "$file" ]] || continue
    bash -n "$file" || fail "bash -n ${file#"$repo_root"/}"
    grep -q '^export LC_ALL=C' "$file" || fail "${file#"$repo_root"/}: missing 'export LC_ALL=C' (English output)"
    if [[ "$have_shellcheck" == true ]]; then
      shellcheck -S warning "$file" || fail "shellcheck ${file#"$repo_root"/}"
    fi
  done < <(repo_files '*.sh')
}

check_seeds() {
  local file block tmp count before
  echo "==> seeds"
  require dash
  command -v ruby >/dev/null || python3 -c 'import yaml' 2>/dev/null || { echo "Need ruby or python3 with PyYAML" >&2; exit 1; }
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/homelab-check.XXXXXX")"
  # shellcheck disable=SC2064 # expand now: tmp is local and gone when the trap fires
  trap "rm -rf '$tmp'" EXIT
  while IFS= read -r file; do
    [[ "$(head -n 1 "$file")" == "#cloud-config" ]] || fail "${file#"$repo_root"/}: first line must be #cloud-config"
    if ! runcmd_blocks "$file" >/dev/null 2>&1; then
      fail "${file#"$repo_root"/}: YAML does not parse"
      continue
    fi
    count=0
    before=$failures
    while IFS= read -r -d '' block; do
      count=$((count + 1))
      printf '%s\n' "$block" > "$tmp/block.sh"
      dash -n "$tmp/block.sh" || fail "${file#"$repo_root"/}: runcmd script block $count (dash -n)"
    done < <(runcmd_blocks "$file")
    [[ "$failures" -gt "$before" ]] || echo "ok ${file#"$repo_root"/} ($count script blocks)"
  done < <(repo_files 'cloud-init.yaml')
}

check_charts() {
  local file deploy_set profile_dir chart overlay args output glued
  echo "==> charts"
  require helm
  require jq
  while IFS= read -r file; do
    jq empty "$file" 2>/dev/null || fail "${file#"$repo_root"/}: invalid JSON"
  done < <(repo_files '*.json')

  while IFS= read -r deploy_set; do
    profile_dir="$(dirname "$deploy_set")"
    while IFS= read -r chart; do
      if [[ ! -x "$repo_root/helm/charts/$chart/scripts/install.sh" ]]; then
        fail "${deploy_set#"$repo_root"/}: chart '$chart' has no executable scripts/install.sh"
        continue
      fi
      if grep -q '^dependencies:' "$repo_root/helm/charts/$chart/Chart.yaml"; then
        add_chart_repos "$repo_root/helm/charts/$chart"
        helm dependency build "$repo_root/helm/charts/$chart" >/dev/null \
          || { fail "helm dependency build $chart"; continue; }
      fi
      overlay="$(jq -r --arg c "$chart" '.releases[] | select(.chart == $c) | .values // empty' "$deploy_set")"
      overlay="${overlay:-$chart/values.yaml}"
      args=()
      if [[ -f "$profile_dir/$overlay" ]]; then
        args=(--values "$profile_dir/$overlay")
      fi
      helm lint --quiet "$repo_root/helm/charts/$chart" ${args[@]+"${args[@]}"} >/dev/null \
        || fail "helm lint $chart (${profile_dir#"$repo_root"/})"
      if output="$(helm template "$chart" "$repo_root/helm/charts/$chart" ${args[@]+"${args[@]}"})"; then
        glued="$(printf '%s\n' "$output" | glued_separators)"
        [[ -z "$glued" ]] || fail "helm template $chart (${profile_dir#"$repo_root"/}): document separator glued to a line: $glued"
      else
        fail "helm template $chart (${profile_dir#"$repo_root"/})"
      fi
      echo "ok $chart with ${profile_dir#"$repo_root"/}"
    done < <(jq -r '.releases[].chart' "$deploy_set")
  done < <(repo_files 'deploy-set.json')
}

# Renders each chart with its test overlays and checks the outcome. "# expect: <text>" lines
# name text the output must contain (pass-*) or the error must contain (fail-*).
check_cases() {
  local case_file chart expect output status count=0 helper first='' built=' ' glued
  echo "==> cases"
  require helm
  while IFS= read -r case_file; do
    chart="$(basename "$(dirname "$case_file")")"
    if [[ "$built" != *" $chart "* ]] && grep -q '^dependencies:' "$repo_root/helm/charts/$chart/Chart.yaml"; then
      add_chart_repos "$repo_root/helm/charts/$chart"
      helm dependency build "$repo_root/helm/charts/$chart" >/dev/null || fail "helm dependency build $chart"
      built="$built$chart "
    fi
    output="$(helm template "$chart" "$repo_root/helm/charts/$chart" --values "$case_file" 2>&1)" && status=0 || status=$?
    count=$((count + 1))
    case "$(basename "$case_file")" in
      pass-*)
        if [[ "$status" -ne 0 ]]; then
          fail "${case_file#"$repo_root"/}: expected to render: $(printf '%s' "$output" | tail -n 1)"
          continue
        fi
        while IFS= read -r expect; do
          [[ "$output" == *"$expect"* ]] || fail "${case_file#"$repo_root"/}: output lacks: $expect"
        done < <(sed -n 's/^# expect: //p' "$case_file")
        glued="$(printf '%s\n' "$output" | glued_separators)"
        [[ -z "$glued" ]] || fail "${case_file#"$repo_root"/}: document separator glued to a line: $glued"
        ;;
      fail-*)
        expect="$(sed -n 's/^# expect: //p' "$case_file" | head -n 1)"
        if [[ -z "$expect" ]]; then
          fail "${case_file#"$repo_root"/}: missing '# expect: <text>' line"
        elif [[ "$status" -eq 0 ]]; then
          fail "${case_file#"$repo_root"/}: expected to fail with: $expect"
        elif [[ "$output" != *"$expect"* ]]; then
          fail "${case_file#"$repo_root"/}: failed, but not with: $expect"
        fi
        ;;
      *) fail "${case_file#"$repo_root"/}: name must start with pass- or fail-" ;;
    esac
  done < <(find "$repo_root/tests/charts" -name '*.yaml' | sort)
  echo "ok $count chart cases"

  # Charts copy the shared env/Secret helper unchanged.
  while IFS= read -r helper; do
    grep -q 'define "homelab.containerEnv"' "$helper" || continue
    if [[ -z "$first" ]]; then
      first="$helper"
    elif ! cmp -s "$first" "$helper"; then
      fail "${helper#"$repo_root"/} differs from ${first#"$repo_root"/}"
    fi
  done < <(repo_files '_helpers.tpl')
  echo "ok shared _helpers.tpl"
}

# Checks the .editorconfig rules on tracked and new (not ignored) text files.
check_format() {
  local file before=$failures
  echo "==> format"
  require git
  while IFS= read -r file; do
    [[ -f "$repo_root/$file" && -s "$repo_root/$file" ]] || continue
    grep -Iq . "$repo_root/$file" || continue  # skip binary files
    [[ -z "$(tail -c 1 "$repo_root/$file")" ]] || fail "$file: no newline at end of file"
    ! grep -q $'\t' "$repo_root/$file" || fail "$file: contains tabs"
    [[ "$file" == *.md ]] || ! grep -qE '[[:space:]]+$' "$repo_root/$file" || fail "$file: trailing whitespace"
  done < <(git -C "$repo_root" ls-files --cached --others --exclude-standard)
  [[ "$failures" -gt "$before" ]] || echo "ok formatting"

  # Relative Markdown links must point at a file or folder (catches moved folders).
  before=$failures
  while IFS= read -r file; do
    [[ -f "$repo_root/$file" ]] || continue
    while IFS= read -r target; do
      target="${target%%#*}"
      [[ -z "$target" || "$target" == *://* || "$target" == mailto:* ]] && continue
      [[ -e "$(dirname "$repo_root/$file")/$target" ]] || fail "$file: broken link $target"
    done < <(grep -oE '\]\([^)[:space:]]+\)' "$repo_root/$file" | sed -E 's/^\]\(//; s/\)$//')
  done < <(git -C "$repo_root" ls-files --cached --others --exclude-standard -- '*.md')
  [[ "$failures" -gt "$before" ]] || echo "ok Markdown links"
}

check_usage() {
  local file status
  echo "==> usage"
  for file in \
    "$repo_root/infratructure/on-premises/virtual-machine/debian12/install.sh" \
    "$repo_root"/helm/deployment/*/*/install.sh \
    "$repo_root"/helm/deployment/*/*/deploy.sh \
    "$repo_root"/helm/charts/homelab-*/scripts/install.sh; do
    [[ -s "$file" ]] || continue
    status=0
    "$file" >/dev/null 2>&1 </dev/null || status=$?
    [[ "$status" -eq 2 ]] || fail "${file#"$repo_root"/}: expected exit 2 without arguments, got $status"
  done
  echo "ok entry points print usage"
}

case "${1:-all}" in
  all) check_scripts; check_seeds; check_charts; check_cases; check_format; check_usage ;;
  scripts) check_scripts ;;
  seeds) check_seeds ;;
  charts) check_charts ;;
  cases) check_cases ;;
  format) check_format ;;
  usage) check_usage ;;
  *) usage ;;
esac

if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed." >&2
  exit 1
fi
echo "All checks passed."
