#!/usr/bin/env bash
# Prepare this tree for Docker. The server source is already in the repo.
# Does not clone upstream and does not download client data.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -f "$root/CMakeLists.txt" ] || [ ! -f "$root/docker-compose.yml" ]; then
  echo "Missing server source (CMakeLists.txt or docker-compose.yml). Clone Milzstream/azeroth-solo; do not expect a separate core checkout." >&2
  exit 1
fi
if [ ! -d "$root/modules/mod-playerbots/src" ]; then
  echo "Missing modules/mod-playerbots source." >&2
  exit 1
fi

mkdir -p "$root/data/sql/custom/db_auth"
cp -f "$root/sql/db_auth/"*.sql "$root/data/sql/custom/db_auth/"
echo "Copied realm-name SQL into data/sql/custom/db_auth (applied by db-import)."
echo "Next: copy .env.example to .env, extract client data into client-data/, then ./scripts/dc.sh"
