#!/usr/bin/env bash
# Start all homelab Docker stacks on boot.
# Called by com.jarvis.homelab.boot.plist after login.
# Waits for MediaStorage to be mounted (arr-stack, stash depend on it).

set -u

export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

LOG="/opt/homebrew/var/log/homelab-boot.log"
HOMELAB="${HOME}/docker"
MOUNT="/Volumes/MediaStorage"
MAX_WAIT=120   # seconds

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

log "=== homelab boot start ==="

# Wait for MediaStorage
elapsed=0
while [[ ! -d "$MOUNT/Movies" ]]; do
  if (( elapsed >= MAX_WAIT )); then
    log "ERROR: $MOUNT not mounted after ${MAX_WAIT}s — starting stacks anyway"
    break
  fi
  log "Waiting for $MOUNT (${elapsed}s)..."
  sleep 5
  (( elapsed += 5 ))
done
[[ -d "$MOUNT/Movies" ]] && log "MediaStorage mounted at ${elapsed}s"

# Give Docker Desktop a moment if it just launched
sleep 5

start_stack() {
  local stack="$1"
  local restart="${2:-no}"
  local dir="${HOMELAB}/${stack}"

  if [[ ! -d "$dir" ]]; then
    log "WARN: $stack directory missing, skipping"
    return
  fi

  log "Starting $stack..."
  cd "$dir" || return
  if [[ "$restart" == "yes" ]]; then
    docker compose down >> "$LOG" 2>&1
  fi
  docker compose up -d >> "$LOG" 2>&1
  log "$stack done"
}

for s in arr-stack romm stash authelia calibre audiobookshelf dnd; do
  start_stack "$s"
done

start_stack komga yes

log "=== homelab boot complete ==="
