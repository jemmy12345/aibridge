#!/usr/bin/env bash
# Build and start AI Bridge locally over plain HTTP (no domain, no certificate).
#
# Usage: ./deploy-local.sh [up|down|logs|reset]
#   up     (default) build the image and start the stack
#   down   stop the stack, keep data
#   logs   follow the application logs
#   reset  stop the stack and DELETE all local data (database, cache, logs)
# Env:    LOCAL_PORT=3000  host port to listen on
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

export LOCAL_PORT="${LOCAL_PORT:-3000}"
COMPOSE=(docker compose -f docker-compose.local.yml --env-file .env.local)

fail() {
    printf 'Error: %s\n' "$1" >&2
    exit 1
}

command -v docker >/dev/null 2>&1 || fail "Required command not found: docker"
docker compose version >/dev/null 2>&1 || fail "Docker Compose plugin is required"
docker info >/dev/null 2>&1 || fail "Docker daemon is not running"

init_env() {
    [[ -f .env.local ]] && return
    command -v openssl >/dev/null 2>&1 || fail "Required command not found: openssl"
    umask 077
    {
        printf 'POSTGRES_PASSWORD=%s\n' "$(openssl rand -hex 24)"
        printf 'REDIS_PASSWORD=%s\n' "$(openssl rand -hex 24)"
        printf 'SESSION_SECRET=%s\n' "$(openssl rand -hex 32)"
    } > .env.local
    printf 'Created .env.local with generated secrets.\n'
}

case "${1:-up}" in
    up)
        init_env
        "${COMPOSE[@]}" config --quiet || fail "Compose configuration is invalid"
        printf 'Building the application image...\n'
        "${COMPOSE[@]}" build new-api
        printf 'Starting services...\n'
        "${COMPOSE[@]}" up -d --remove-orphans

        ready=false
        for _ in {1..60}; do
            if curl --silent --fail --output /dev/null "http://127.0.0.1:$LOCAL_PORT/api/status"; then
                ready=true
                break
            fi
            sleep 2
        done
        [[ "$ready" == true ]] || {
            "${COMPOSE[@]}" ps
            fail "Health check failed. Review logs with: ./deploy-local.sh logs"
        }
        printf '\nAI Bridge is ready: http://localhost:%s\n' "$LOCAL_PORT"
        printf 'Complete the initial setup wizard in your browser.\n'
        ;;
    down)
        init_env
        "${COMPOSE[@]}" down
        ;;
    logs)
        init_env
        "${COMPOSE[@]}" logs -f new-api
        ;;
    reset)
        init_env
        read -r -p "This deletes ALL local AI Bridge data. Type 'yes' to continue: " answer
        [[ "$answer" == "yes" ]] || fail "Aborted"
        "${COMPOSE[@]}" down -v
        rm -rf data-local logs-local .env.local
        printf 'Local data removed.\n'
        ;;
    *)
        fail "Unknown command: $1 (use up|down|logs|reset)"
        ;;
esac
