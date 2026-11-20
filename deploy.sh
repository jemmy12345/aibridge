#!/usr/bin/env bash
set -Eeuo pipefail

DOMAIN="www.aibridge.xin"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

fail() {
    printf 'Error: %s\n' "$1" >&2
    exit 1
}

for command in docker openssl curl; do
    command -v "$command" >/dev/null 2>&1 || fail "Required command not found: $command"
done

docker compose version >/dev/null 2>&1 || fail "Docker Compose plugin is required"

[[ -f cert/fullchain.pem ]] || fail "Missing cert/fullchain.pem"
[[ -f cert/privkey.pem ]] || fail "Missing cert/privkey.pem"

openssl x509 -in cert/fullchain.pem -noout -checkhost "$DOMAIN" >/dev/null ||
    fail "cert/fullchain.pem is not valid for $DOMAIN"
openssl x509 -in cert/fullchain.pem -noout -checkend 0 >/dev/null ||
    fail "The certificate in cert/fullchain.pem has expired"

cert_public_key="$(openssl x509 -in cert/fullchain.pem -pubkey -noout | openssl pkey -pubin -outform DER | openssl dgst -sha256)"
private_public_key="$(openssl pkey -in cert/privkey.pem -pubout -outform DER | openssl dgst -sha256)"
[[ "$cert_public_key" == "$private_public_key" ]] ||
    fail "cert/privkey.pem does not match the certificate in cert/fullchain.pem"

chmod 600 cert/privkey.pem
chmod 644 cert/fullchain.pem

if [[ ! -f .env ]]; then
    project_name="${COMPOSE_PROJECT_NAME:-$(basename "$ROOT_DIR" | tr '[:upper:]' '[:lower:]')}"
    if docker volume inspect "${project_name}_pg_data" >/dev/null 2>&1; then
        fail "Existing PostgreSQL volume found without .env. Restore the original .env to retain database access."
    fi

    umask 077
    {
        printf 'POSTGRES_PASSWORD=%s\n' "$(openssl rand -hex 24)"
        printf 'REDIS_PASSWORD=%s\n' "$(openssl rand -hex 24)"
        printf 'SESSION_SECRET=%s\n' "$(openssl rand -hex 32)"
    } > .env
    printf 'Created .env with generated secrets (permissions restricted).\n'
fi
chmod 600 .env

docker compose config --quiet || fail "Compose configuration is invalid"

[[ -f web/dist/index.html ]] ||
    fail "Missing web/dist. Run ./build-web.sh --push on a machine where Bun works, then git pull here"

printf 'Building the application image...\n'
docker compose build new-api
printf 'Starting the application and HTTPS reverse proxy...\n'
docker compose up -d --remove-orphans

ready=false
for attempt in {1..60}; do
    if curl --silent --fail --output /dev/null \
        --resolve "$DOMAIN:443:127.0.0.1" "https://$DOMAIN/api/status"; then
        ready=true
        break
    fi
    sleep 2
done

[[ "$ready" == true ]] || {
    docker compose ps
    fail "HTTPS health check failed. Review service status with: docker compose logs new-api nginx"
}

printf '\nDeployment is ready: https://%s\n' "$DOMAIN"
printf 'Complete the initial setup wizard in your browser.\n'
