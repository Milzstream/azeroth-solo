#!/usr/bin/env bash
# Check out the pinned Playerbot fork and mod-playerbots. Does not download client data.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$root/pins.env"
src="$root/src/azerothcore-wotlk"

checkout() {
  local url="$1" sha="$2" dest="$3"
  if [ ! -d "$dest/.git" ]; then
    mkdir -p "$(dirname "$dest")"
    git clone --filter=blob:none --no-checkout "$url" "$dest"
  fi
  git -C "$dest" fetch --depth 1 origin "$sha"
  git -C "$dest" checkout --detach FETCH_HEAD
  echo "pinned $(git -C "$dest" rev-parse HEAD) $dest"
}

checkout "$AZEROTHCORE_REPO" "$AZEROTHCORE_SHA" "$src"
checkout "$PLAYERBOTS_REPO" "$PLAYERBOTS_SHA" "$src/modules/mod-playerbots"

mkdir -p "$src/data/sql/custom/db_auth"
cp -f "$root/sql/db_auth/"*.sql "$src/data/sql/custom/db_auth/"
echo "Copied realm-name SQL into data/sql/custom/db_auth (applied by db-import)."
echo "Next: copy .env.example to .env, extract client data into data/client, then ./scripts/dc.sh"
