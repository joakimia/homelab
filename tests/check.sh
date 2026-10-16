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
#   ./check.sh cases       helm template with each tests/helm/charts/<chart>/{pass,fail}-*.yaml overlay:
#                          pass-* must render and contain each "# expect:" text, fail-* must
#                          fail with it. Fetches chart dependencies (needs network).
#                          Shared _helpers.tpl files must be identical.
#   ./check.sh format      .editorconfig basics on files in Git: final newline, no tabs, and no
#                          trailing whitespace (Markdown excepted); relative Markdown links resolve.
#   ./check.sh provisioning  Runs the provisioning install.sh for each tests/infratructure/.../debian12/{pass,fail}-*.txt
#                          case with stub ssh and scp: the output, the remote calls, the copied
#                          seed, and any seed ISO must match the case's "# expect" lines.
#   ./check.sh usage       Entry-point scripts and the base chart installers exit 2 and print
#                          usage without arguments.
#   ./check.sh schema      Docker: cloud-init schema (Debian 12's cloud-init) on the user-data
#                          install.sh renders from each seed.
#   ./check.sh nodes       Docker: the functions install.sh runs on the nodes, in debian:12 with
#                          a microk8s stub and fake RKE2 token files.
#
# Needs bash, jq, helm, dash, and ruby or python3 with PyYAML. shellcheck is optional
# locally (a notice is printed) and required when CI=true. The Docker groups take about a
# minute, so the default run includes them only when CI=true; run them locally by name.
set -euo pipefail
export LC_ALL=C  # English messages from bash and tools, whatever the local language

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
provisioning_dir="$repo_root/infratructure/on-premises/virtual-machine/debian12"
failures=0

usage() {
  echo "Usage: $0 [scripts|seeds|charts|cases|format|provisioning|usage|schema|nodes]" >&2
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
  local file deploy_set profile_dir chart overlay args output glued rendered host
  echo "==> charts"
  require helm
  require jq
  while IFS= read -r file; do
    jq empty "$file" 2>/dev/null || fail "${file#"$repo_root"/}: invalid JSON"
  done < <(repo_files '*.json')

  while IFS= read -r deploy_set; do
    profile_dir="$(dirname "$deploy_set")"
    rendered=''
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
        rendered+="$output"$'\n'
      else
        fail "helm template $chart (${profile_dir#"$repo_root"/})"
      fi
      echo "ok $chart with ${profile_dir#"$repo_root"/}"
    done < <(jq -r '.releases[].chart' "$deploy_set")
    # Every homepage link must reach an Ingress host the same profile installs.
    while IFS= read -r host; do
      grep -qE "^[[:space:]]*- host: \"?$host\"?$" <<<"$rendered" \
        || fail "${profile_dir#"$repo_root"/}: homepage links to $host, but no Ingress in the profile has that host"
    done < <(sed -nE 's#.*<a href="https://([^:/"]+).*#\1#p' <<<"$rendered" | sort -u)
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
  done < <(find "$repo_root/tests/helm/charts" -name '*.yaml' | sort)
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

# Fails unless Docker can run containers.
require_docker() {
  command -v docker >/dev/null && docker info >/dev/null 2>&1 || { echo "Docker is required for '$1'" >&2; exit 1; }
}

# Writes stub ssh and scp commands and a test SSH key to dir. The stubs log each call to
# dir/calls (ssh stdin to dir/stdin), copy scp sources to dir/scp/, and answer ssh with the first
# line of dir/replies ("<text> => <output>", or "<text> => !exit <n>" to fail) whose text
# appears in "<target> <command>".
# Defaults: hostname prints homelab-<host>, and the default route's source is 192.0.2.10 for
# hosts starting with cp and 192.0.2.20 for others.
write_stubs() {
  local dir=$1
  mkdir -p "$dir/bin" "$dir/scp" "$dir/work"
  : > "$dir/calls"
  touch "$dir/replies"
  echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHRlc3Qta2V5LWZvci1jaGVjay1zaA test@check' > "$dir/key.pub"
  cat > "$dir/bin/ssh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
control=''
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) shift 2 ;;
    -O) control=$2; shift 2 ;;
    -t | -tt | -q) shift ;;
    *) break ;;
  esac
done
target=$1
shift
if [[ -n "$control" ]]; then
  echo "ssh -O $control $target" >> "$STUB_DIR/calls"
  exit 0
fi
command="$*"
# Log "sudo bash -c <%q-quoted script>" decoded, so cases can match the script text.
if [[ "$command" == "sudo bash -c "* ]]; then
  eval "decoded=( ${command#sudo bash -c } )"
  command="sudo bash -c ${decoded[0]}"
fi
printf 'ssh %s %s\n' "$target" "$command" >> "$STUB_DIR/calls"
stdin=$(cat)
[[ -z "$stdin" ]] || printf '%s\n' "$stdin" >> "$STUB_DIR/stdin"
while IFS= read -r line; do
  if [[ "$target $command" == *"${line%% => *}"* ]]; then
    reply=${line#* => }
    [[ "$reply" != '!exit '* ]] || exit "${reply#!exit }"
    printf '%s\n' "$reply"
    exit 0
  fi
done < "$STUB_DIR/replies"
host=${target#*@}
case "$command" in
  hostname) echo "homelab-$host" ;;
  'ip -4 route get 1.1.1.1')
    case "$host" in cp*) ip=192.0.2.10 ;; *) ip=192.0.2.20 ;; esac
    echo "1.1.1.1 via 192.0.2.1 dev eth0 src $ip uid 1000" ;;
  'printf %s "$HOME"') printf %s /home/debian ;;
esac
STUB
  cat > "$dir/bin/scp" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) shift 2 ;;
    -q) shift ;;
    *) args+=("$1"); shift ;;
  esac
done
printf 'scp %s\n' "${args[*]}" >> "$STUB_DIR/calls"
for arg in "${args[@]}"; do
  if [[ "$arg" != *:* && -f "$arg" ]]; then
    cp "$arg" "$STUB_DIR/scp/"
  fi
done
STUB
  chmod +x "$dir/bin/ssh" "$dir/bin/scp"
}

# Extracts an ISO 9660 image with bsdtar or xorriso; returns 1 when neither is available.
extract_iso() {
  if tar --version 2>/dev/null | grep -q bsdtar; then
    tar -xf "$1" -C "$2"
  elif command -v bsdtar >/dev/null; then
    bsdtar -xf "$1" -C "$2"
  elif command -v xorriso >/dev/null; then
    xorriso -osirrox on -indev "$1" -extract / "$2" >/dev/null 2>&1
  else
    return 1
  fi
}

# Runs the provisioning install.sh from dir/work with the stubs from write_stubs. Sets
# run_status, and run_output to the script's output followed by sections for the calls
# ("== calls"), the copied text files ("== scp <name>"), and seed ISO files ("== iso <name>").
run_install() {
  local dir=$1 file entry
  shift
  run_status=0
  run_output="$(cd "$dir/work" && STUB_DIR="$dir" PATH="$dir/bin:$PATH" HOMELAB_SSH_PUBLIC_KEY="$dir/key.pub" \
    "$provisioning_dir/install.sh" "$@" 2>&1 </dev/null)" || run_status=$?
  run_output+=$'\n== calls\n'"$(cat "$dir/calls")"
  for file in "$dir"/scp/*; do
    [[ -f "$file" ]] && grep -Iq . "$file" || continue
    run_output+=$'\n== scp '"$(basename "$file")"$'\n'"$(cat "$file")"
  done
  for file in "$dir"/work/*.iso; do
    [[ -f "$file" ]] || continue
    mkdir -p "$dir/iso"
    extract_iso "$file" "$dir/iso" || { run_output+=$'\n== iso: cannot extract'; continue; }
    for entry in "$dir"/iso/*; do
      [[ -f "$entry" ]] || continue
      run_output+=$'\n== iso '"$(basename "$entry")"$'\n'"$(cat "$entry")"
    done
  done
}

# Runs each provisioning case (tests/ mirrors the provisioning folder): "# args:" (split on spaces), "# reply:" lines for the ssh
# stub, then "# expect:" (must appear), "# expect-not:" (must not appear), "# expect-order:"
# (must appear in this order), and "# exit:" (exit status). pass-* must exit 0, fail-* non-zero.
check_provisioning() {
  local case_file name tmp dir args status expect rest count=0 skipped=0 iso_tool=false tool
  echo "==> provisioning"
  for tool in hdiutil xorriso genisoimage mkisofs; do
    command -v "$tool" >/dev/null && iso_tool=true
  done
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/homelab-check.XXXXXX")"
  # shellcheck disable=SC2064 # expand now: tmp is local and gone when the trap fires
  trap "rm -rf '$tmp'" EXIT
  while IFS= read -r case_file; do
    name="${case_file#"$repo_root"/}"
    args="$(sed -n 's/^# args: //p' "$case_file")"
    if [[ " $args " == *" --iso "* && "$iso_tool" == false ]]; then
      [[ "${CI:-}" != true ]] || { fail "$name: no ISO tool (install xorriso)"; continue; }
      skipped=$((skipped + 1))
      continue
    fi
    dir="$tmp/$(basename "$case_file" .txt)"
    write_stubs "$dir"
    sed -n 's/^# reply: //p' "$case_file" > "$dir/replies"
    # shellcheck disable=SC2086 # the case's arguments are split on spaces
    run_install "$dir" $args
    count=$((count + 1))

    case "$(basename "$case_file")" in
      pass-*) [[ "$run_status" -eq 0 ]] || fail "$name: exited $run_status: $(printf '%s' "$run_output" | sed -n '/^== calls$/q;p' | tail -n 1)" ;;
      fail-*) [[ "$run_status" -ne 0 ]] || fail "$name: expected a non-zero exit" ;;
      *) fail "$name: name must start with pass- or fail-"; continue ;;
    esac
    status="$(sed -n 's/^# exit: //p' "$case_file")"
    [[ -z "$status" || "$status" == "$run_status" ]] || fail "$name: expected exit $status, got $run_status"
    grep -q '^# expect' "$case_file" || fail "$name: no '# expect' lines"
    while IFS= read -r expect; do
      [[ "$run_output" == *"$expect"* ]] || fail "$name: output lacks: $expect"
    done < <(sed -n 's/^# expect: //p' "$case_file")
    while IFS= read -r expect; do
      [[ "$run_output" != *"$expect"* ]] || fail "$name: output contains: $expect"
    done < <(sed -n 's/^# expect-not: //p' "$case_file")
    rest="$run_output"
    while IFS= read -r expect; do
      if [[ "$rest" == *"$expect"* ]]; then
        rest="${rest#*"$expect"}"
      else
        fail "$name: out of order or missing: $expect"
      fi
    done < <(sed -n 's/^# expect-order: //p' "$case_file")
  done < <(find "$repo_root/tests/${provisioning_dir#"$repo_root"/}" -name '*.txt' | sort)
  echo "ok $count provisioning cases"
  [[ "$skipped" -eq 0 ]] || echo "Notice: skipped $skipped --iso case(s): no ISO tool (CI installs xorriso)."
}

# Renders the user-data of every seed through install.sh (stub ssh) and validates it with the
# cloud-init of Debian 12, the version the nodes run.
check_schema() {
  local file seed tmp dir results
  echo "==> schema"
  require_docker schema
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/homelab-check.XXXXXX")"
  # shellcheck disable=SC2064 # expand now: tmp is local and gone when the trap fires
  trap "rm -rf '$tmp'" EXIT
  while IFS= read -r file; do
    seed="$(dirname "${file#"$provisioning_dir"/}")"
    dir="$tmp/${seed//\//-}"
    write_stubs "$dir"
    # shellcheck disable=SC2046 # distro and role become two arguments
    run_install "$dir" $(printf '%s' "$seed" | tr / ' ') debian@node
    if [[ "$run_status" -ne 0 || ! -f "$dir/scp/user-data" ]]; then
      fail "schema: install.sh could not render $seed"
      continue
    fi
    mkdir -p "$tmp/user-data"
    cp "$dir/scp/user-data" "$tmp/user-data/${seed//\//-}.yaml"
  done < <(find "$provisioning_dir" -name cloud-init.yaml | sort)

  results="$(docker run --rm -v "$tmp/user-data:/seeds:ro" debian:12 sh -c '
    apt-get update -qq >/dev/null && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends cloud-init >/dev/null 2>&1 || { echo "FAIL apt-get install cloud-init"; exit 0; }
    for f in /seeds/*.yaml; do
      if out=$(cloud-init schema --config-file "$f" 2>&1); then echo "ok ${f#/seeds/}"; else echo "FAIL ${f#/seeds/}: $out" | tr "\n" " "; echo; fi
    done' 2>&1)" || fail "schema: docker run failed"
  while IFS= read -r file; do
    case "$file" in
      ok\ *) echo "ok schema ${file#ok }" ;;
      FAIL\ *) fail "schema ${file#FAIL }" ;;
    esac
  done <<<"$results"
}

# Runs in a debian:12 container: tests the functions install.sh sends to the nodes, taken from
# the install.sh given, with a microk8s stub. Prints "FAIL <text>" per failed assertion.
node_function_tests() {
  set -uo pipefail
  local install=$1 fns cp_file
  fns="$(awk '/^(set_hosts_entry|prepare_join|join_node|export_rke2_token|write_rke2_join)\(\) \{/,/^\}/' "$install")"
  assert() { local text=$1; shift; if "$@"; then echo "ok $text"; else echo "FAIL $text"; fi; }
  run() { bash -c "$fns; $*" >/tmp/out 2>&1; }
  fails() { ! run "$@"; }
  for cp_file in set_hosts_entry prepare_join join_node export_rke2_token write_rke2_join; do
    assert "install.sh defines $cp_file" bash -c "$fns; declare -F $cp_file >/dev/null"
  done
  useradd -m debian && install -d -o debian /home/debian/.kube && cd /home/debian || exit 1
  mkdir -p /snap/bin
  cat > /snap/bin/microk8s <<'STUB'
#!/bin/sh
echo "microk8s $*" >> /tmp/calls
case "$1" in
  add-node) printf 'microk8s join 10.1.0.1:25000/other/hash\nmicrok8s join 192.0.2.10:25000/tok/hash\n' ;;
  kubectl) [ -f /tmp/node-exists ] ;;
  config) printf 'clusters:\n- cluster:\n    server: https://192.0.2.10:16443\n' ;;
esac
STUB
  chmod +x /snap/bin/microk8s
  printf '127.0.0.1 localhost\n127.0.1.1 debian\n' > /etc/hosts

  run set_hosts_entry 192.0.2.20 homelab-wk0 && run set_hosts_entry 192.0.2.21 homelab-wk0
  assert "set_hosts_entry replaces its entry" test "$(grep -c homelab-wk0 /etc/hosts)" = 1
  assert "set_hosts_entry writes the new address" grep -qx '192.0.2.21 homelab-wk0 # homelab-join' /etc/hosts
  assert "set_hosts_entry keeps other lines" grep -qx '127.0.1.1 debian' /etc/hosts

  run prepare_join homelab-wk0 192.0.2.20 192.0.2.10 join-url debian
  assert "prepare_join picks the control plane's URL" test "$(cat join-url)" = 192.0.2.10:25000/tok/hash
  assert "prepare_join file is 0600 and owned by debian" test "$(stat -c '%a %U' join-url)" = '600 debian'
  touch /tmp/node-exists
  run prepare_join homelab-wk0 192.0.2.20 192.0.2.10 join-url debian
  assert "prepare_join writes nothing for an existing node" test ! -s join-url
  rm /tmp/node-exists
  assert "prepare_join fails without a URL for the address" fails prepare_join wk 192.0.2.20 192.0.2.99 join-url debian

  : > /tmp/calls
  echo 192.0.2.10:25000/tok/hash > join-url
  run join_node homelab-cp0 192.0.2.10 join-url worker-node debian
  assert "join_node joins a worker with --worker" grep -qx 'microk8s join 192.0.2.10:25000/tok/hash --worker' /tmp/calls
  assert "join_node removes the URL file" test ! -e join-url
  assert "join_node adds the control plane to /etc/hosts" grep -qx '192.0.2.10 homelab-cp0 # homelab-join' /etc/hosts
  : > /tmp/calls
  echo 192.0.2.10:25000/tok/hash > join-url
  run join_node homelab-cp0 192.0.2.10 join-url control-plane-node debian
  assert "join_node joins a control plane without --worker" grep -qx 'microk8s join 192.0.2.10:25000/tok/hash' /tmp/calls
  assert "join_node rewrites the kubeconfig for 127.0.0.1" grep -q 'server: https://127.0.0.1:16443' .kube/config
  : > /tmp/calls
  : > join-url
  run join_node homelab-cp0 192.0.2.10 join-url worker-node debian
  assert "join_node skips the join for an empty URL file" test ! -s /tmp/calls

  cp_file=/var/lib/rancher/rke2/server
  mkdir -p "$cp_file"
  echo 'K10abc::server:secret' > "$cp_file/node-token"
  run export_rke2_token worker-node token debian
  assert "export_rke2_token uses the server token without an agent token" test "$(cat token)" = 'K10abc::server:secret'
  assert "export_rke2_token file is 0600 and owned by debian" test "$(stat -c '%a %U' token)" = '600 debian'
  echo 'K10abc::node:agent' > "$cp_file/agent-token"
  run export_rke2_token worker-node token debian
  assert "export_rke2_token gives workers the agent token" test "$(cat token)" = 'K10abc::node:agent'
  run export_rke2_token control-plane-node token debian
  assert "export_rke2_token gives control planes the server token" test "$(cat token)" = 'K10abc::server:secret'
  rm -rf /var/lib/rancher/rke2/server
  assert "export_rke2_token fails on a machine that is no RKE2 server" fails export_rke2_token worker-node token debian

  echo 'K10abc::server:secret' > token
  run write_rke2_join https://192.0.2.10:9345 token
  cp_file=/etc/rancher/rke2/config.yaml.d/50-join.yaml
  assert "write_rke2_join writes server and token" test "$(cat "$cp_file")" = "$(printf 'server: https://192.0.2.10:9345\ntoken: K10abc::server:secret')"
  assert "write_rke2_join file is 0600 and owned by root" test "$(stat -c '%a %U' "$cp_file")" = '600 root'
  assert "write_rke2_join removes the token file" test ! -e token
  rm -f "$cp_file"
  : > token
  assert "write_rke2_join fails on an empty token" fails write_rke2_join https://x:9345 token
  assert "write_rke2_join writes nothing for an empty token" test ! -e "$cp_file"
}

# Runs node_function_tests in debian:12 against this checkout's install.sh.
check_nodes() {
  local results line
  echo "==> nodes"
  require_docker nodes
  results="$(docker run --rm -v "$provisioning_dir/install.sh:/install.sh:ro" debian:12 \
    bash -c "$(declare -f node_function_tests); node_function_tests /install.sh" 2>&1)" || fail "nodes: docker run failed"
  while IFS= read -r line; do
    case "$line" in
      ok\ *) echo "ok nodes: ${line#ok }" ;;
      FAIL\ *) fail "nodes: ${line#FAIL }" ;;
      *) [[ -z "$line" ]] || echo "$line" ;;
    esac
  done <<<"$results"
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
  all)
    check_scripts; check_seeds; check_charts; check_cases; check_format; check_provisioning; check_usage
    if [[ "${CI:-}" == true ]]; then
      check_schema; check_nodes
    else
      echo "Notice: skipping the Docker groups schema and nodes (about a minute); CI runs them. Run them with tests/check.sh schema or nodes."
    fi ;;
  scripts) check_scripts ;;
  seeds) check_seeds ;;
  charts) check_charts ;;
  cases) check_cases ;;
  format) check_format ;;
  provisioning) check_provisioning ;;
  usage) check_usage ;;
  schema) check_schema ;;
  nodes) check_nodes ;;
  *) usage ;;
esac

if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed." >&2
  exit 1
fi
echo "All checks passed."
