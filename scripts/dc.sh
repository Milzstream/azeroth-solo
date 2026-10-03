#!/usr/bin/env bash
# docker compose against this repo, with the local override and .env.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
if [ ! -f "$root/.env" ]; then
  echo "Missing .env. Run: cp .env.example .env" >&2
  exit 1
fi
if [ ! -f "$root/docker-compose.yml" ]; then
  echo "Missing docker-compose.yml. This repo should already contain the server source." >&2
  exit 1
fi
exec docker compose \
  --project-directory "$root" \
  -f "$root/docker-compose.yml" \
  -f "$root/docker-compose.override.yml" \
  --env-file "$root/.env" \
  "$@"
