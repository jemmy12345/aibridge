#!/usr/bin/env bash
# Build the frontend (web/dist) on a machine where Bun runs, and optionally
# commit/push it so the server can `git pull` and build the image from it.
#
# Usage: ./build-web.sh           build web/dist only
#        ./build-web.sh --commit  build, then commit web/dist
#        ./build-web.sh --push    build, commit web/dist, then git push
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

mode="${1:-}"
case "$mode" in
    ""|--commit|--push) ;;
    *) echo "Usage: $0 [--commit|--push]" >&2; exit 1 ;;
esac

command -v bun >/dev/null 2>&1 || { echo "Error: bun is required on this machine" >&2; exit 1; }

(
    cd web
    bun install --frozen-lockfile
    DISABLE_ESLINT_PLUGIN=true VITE_REACT_APP_VERSION="$(cat ../VERSION)" bun run build
)
[[ -f web/dist/index.html ]] || { echo "Error: web/dist/index.html missing after build" >&2; exit 1; }
echo "Frontend built: $ROOT_DIR/web/dist"

[[ -n "$mode" ]] || exit 0

git add -A web/dist
if git diff --cached --quiet -- web/dist; then
    echo "web/dist unchanged, nothing to commit."
else
    git commit -m "build(web): update dist" -- web/dist
fi

if [[ "$mode" == "--push" ]]; then
    git push
    echo "Pushed. On the server run: git pull && ./deploy.sh"
fi
