#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

exec "$script_dir/../generate-cloud-init-iso.sh" control-plane-node "$@"
