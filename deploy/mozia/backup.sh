#!/bin/sh
set -eu
umask 077
cd "$(dirname "$0")"
dest="/opt/mozia/backups/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$dest"
docker compose --env-file /opt/mozia/secrets/stack.env exec -T newapi-postgres pg_dump -U newapi -d newapi -Fc > "$dest/newapi.dump"
docker compose --env-file /opt/mozia/secrets/stack.env exec -T sub2api-postgres pg_dump -U sub2api -d sub2api -Fc > "$dest/sub2api.dump"
cp -a /opt/mozia/secrets "$dest/secrets"
printf 'Backup created: %s\n' "$dest"
