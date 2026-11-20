#!/usr/bin/env bash
# Build the frontend (web/dist) on a machine where Bun runs, optionally upload it.
#
# Usage: ./build-web.sh                 build web/dist only
#        ./build-web.sh user@host:path  build, then rsync web/dist to the server,
#                                       e.g. ./build-web.sh root@1.2.3.4:~/aibridge
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR/web"

command -v bun >/dev/null 2>&1 || { echo "Error: bun is required on this machine" >&2; exit 1; }

bun install --frozen-lockfile
DISABLE_ESLINT_PLUGIN=true VITE_REACT_APP_VERSION="$(cat ../VERSION)" bun run build
[[ -f dist/index.html ]] || { echo "Error: web/dist/index.html missing after build" >&2; exit 1; }
echo "Frontend built: $ROOT_DIR/web/dist"

if [[ $# -ge 1 ]]; then
    command -v rsync >/dev/null 2>&1 || { echo "Error: rsync is required for upload" >&2; exit 1; }
    rsync -az --delete dist/ "${1%/}/web/dist/"
    echo "Uploaded to ${1%/}/web/dist. Now run ./deploy.sh on the server."
fi
