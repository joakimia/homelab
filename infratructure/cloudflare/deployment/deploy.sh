#!/usr/bin/env bash
# Runs OpenTofu for one Cloudflare environment (a folder next to this script, for example dev),
# from the Mac or in GitHub Actions. Loads .env.local from the repository root when it exists,
# maps CLOUDFLARE_ACCESS_EMAILS to TF_VAR_access_emails and R2_* to the AWS_* names the S3
# backend reads, and runs tofu with -chdir. Plan files go to ./.local/cloudflare/ (ignored).
#
#   ./deploy.sh <env> init      Initialize the folder: providers from the lock file, state in R2.
#   ./deploy.sh <env> plan      Init, then write ./.local/cloudflare/<env>.tfplan and print it
#                               (also to the job summary in GitHub Actions).
#   ./deploy.sh <env> apply     Apply exactly the plan file from the last plan, then delete it.
#   ./deploy.sh <env> migrate   One time: copy the state from the old local backend
#                               (.local/cloudflare/<env>.tfstate) to R2.
set -euo pipefail
export LC_ALL=C  # English messages from bash and tools, whatever the local language

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../../.." && pwd)"
env_file="$repo_root/.env.local"

usage() {
  echo "Usage: $0 <env> init|plan|apply|migrate" >&2
  echo "  <env> is a folder in ${script_dir#"$repo_root"/}/, for example dev." >&2
  exit 2
}

check_env() {
  [[ "$1" =~ ^[a-z0-9-]+$ && "$1" != modules && -f "$script_dir/$1/versions.tf" ]] \
    || { echo "Unknown environment '$1' (expected a folder in ${script_dir#"$repo_root"/}/)" >&2; usage; }
}

# Fails with a hint for each required variable that is empty.
require_vars() {
  local name missing=0
  for name in "$@"; do
    if [[ -z "${!name:-}" ]]; then
      echo "$name is not set: add it to .env.local at the repository root, or to the GitHub environment's secrets." >&2
      missing=1
    fi
  done
  [[ "$missing" -eq 0 ]] || exit 1
}

# Loads .env.local (absent in CI) and maps the repository's names to what tofu reads.
load_env() {
  if [[ -f "$env_file" ]]; then
    set -a
    # shellcheck source=/dev/null
    . "$env_file"
    set +a
  fi
  require_vars R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY
  export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
  # Other AWS settings from the shell would be sent to R2 as well.
  unset AWS_SESSION_TOKEN AWS_PROFILE
}

# Checks the Cloudflare variables plan and apply need, and masks each Access address in
# GitHub Actions logs (the secret holds the whole list, so GitHub masks only the full string).
load_cloudflare_env() {
  local email
  require_vars CLOUDFLARE_API_TOKEN CLOUDFLARE_ACCESS_EMAILS
  export TF_VAR_access_emails="$CLOUDFLARE_ACCESS_EMAILS"
  if [[ "${GITHUB_ACTIONS:-}" == true ]]; then
    while IFS= read -r -d , email; do
      email="$(echo "$email" | tr -d '[:space:]')"
      [[ -z "$email" ]] || echo "::add-mask::$email"
    done <<<"$CLOUDFLARE_ACCESS_EMAILS,"
  fi
}

# Initializes the environment folder with the R2 backend and the locked provider versions.
init_env() {
  echo "Initializing $env_name (state in R2)..."
  tofu -chdir="$env_dir" init -input=false -lockfile=readonly
}

# Writes the plan file and prints it; in GitHub Actions also to the job summary.
plan_env() {
  umask 077
  mkdir -p "$(dirname "$plan_file")"
  chmod 700 "$(dirname "$plan_file")"
  echo "Planning $env_name..."
  tofu -chdir="$env_dir" plan -input=false -lock-timeout=5m -out="$plan_file"
  echo "Plan written to $plan_file (it holds secrets; apply it with: $0 $env_name apply)"
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
      echo "### OpenTofu plan: $env_name"
      echo
      echo '````text'
      tofu -chdir="$env_dir" show -no-color "$plan_file"
      echo '````'
    } >>"$GITHUB_STEP_SUMMARY"
  fi
}

# Applies the saved plan; tofu refuses it if the state changed since the plan.
apply_env() {
  [[ -f "$plan_file" ]] || { echo "No plan file $plan_file: run $0 $env_name plan first." >&2; exit 1; }
  echo "Applying $plan_file..."
  tofu -chdir="$env_dir" apply -input=false -lock-timeout=5m "$plan_file"
  rm -f "$plan_file"
}

# Copies the state from the old local backend to R2. tofu finds the old backend in
# .terraform/terraform.tfstate, written by an earlier init with the local backend.
migrate_env() {
  local old_state="$repo_root/.local/cloudflare/$env_name.tfstate"
  [[ -f "$old_state" ]] || { echo "No old state at $old_state: nothing to migrate." >&2; exit 1; }
  grep -q '"type": "local"' "$env_dir/.terraform/terraform.tfstate" 2>/dev/null \
    || { echo "$env_dir/.terraform does not point at the local backend; run tofu init there with the old backend first." >&2; exit 1; }
  echo "Copying $old_state to R2..."
  tofu -chdir="$env_dir" init -input=false -lockfile=readonly -migrate-state -force-copy
  echo "Done. Check with: $0 $env_name plan. Keep the old file as a backup until then."
}

[[ $# -eq 2 ]] || usage
check_env "$1"
env_name=$1
env_dir="$script_dir/$env_name"
plan_file="$PWD/.local/cloudflare/$env_name.tfplan"
command -v tofu >/dev/null || { echo "tofu (OpenTofu) is required, see mise.toml" >&2; exit 1; }

case "$2" in
  init) load_env; init_env ;;
  plan) load_env; load_cloudflare_env; init_env; plan_env ;;
  apply) load_env; load_cloudflare_env; apply_env ;;
  migrate) load_env; migrate_env ;;
  *) usage ;;
esac
