#!/usr/bin/env bash
# Apply compose changes across all stacks.
# Recreates containers with the latest docker-compose.yml settings.
#
# Usage: ./scripts/apply-all.sh

set -u
HOMELAB="${HOME}/docker"

# Stacks that just need `up -d` (Docker compose detects config changes and recreates)
SIMPLE_STACKS=(arr-stack romm stash authelia calibre audiobookshelf dnd)

# Stacks that need a full down/up cycle (e.g., network changes don't apply with `up -d` alone)
RESTART_STACKS=(komga)

apply_stack() {
  local stack="$1"
  local restart="${2:-no}"
  local dir="${HOMELAB}/${stack}"

  if [[ ! -d "$dir" ]]; then
    printf "  ⚠  %-12s  directory missing\n" "$stack"
    return
  fi

  echo "── ${stack} ──"
  cd "$dir" || return

  if [[ "$restart" == "yes" ]]; then
    docker compose down 2>&1 | tail -5
  fi
  docker compose up -d 2>&1 | tail -10
  echo ""
}

for s in "${SIMPLE_STACKS[@]}"; do
  apply_stack "$s" "no"
done

for s in "${RESTART_STACKS[@]}"; do
  apply_stack "$s" "yes"
done

echo "── healthcheck ──"
"${HOMELAB}/scripts/healthcheck.sh" --quiet
