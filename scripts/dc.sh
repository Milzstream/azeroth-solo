#!/usr/bin/env bash
# docker compose against the pinned fork, with this repo's override and .env.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
if [ ! -f "$root/.env" ]; then
  echo "Missing .env. Run: cp .env.example .env" >&2
  exit 1
fi
if [ ! -f "$root/src/azerothcore-wotlk/docker-compose.yml" ]; then
  echo "Missing checkout. Run: ./scripts/bootstrap.sh" >&2
  exit 1
fi
exec docker compose \
  --project-directory "$root/src/azerothcore-wotlk" \
  -f "$root/src/azerothcore-wotlk/docker-compose.yml" \
  -f "$root/docker-compose.override.yml" \
  --env-file "$root/.env" \
  "$@"
