#!/usr/bin/env bash
# Homelab health check — pings each *.grfns.com URL and reports status.
# Exit code: 0 if all healthy, 1 if any failure.
#
# Usage:
#   ./healthcheck.sh                    # human output
#   ./healthcheck.sh --quiet            # only print failures
#   ./healthcheck.sh --notify           # macOS notification on failures
#
# Schedule via launchd: see scripts/com.jarvis.homelab.healthcheck.plist

set -u

QUIET=0
NOTIFY=0
for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=1 ;;
    --notify) NOTIFY=1 ;;
  esac
done

# Public endpoints (via cloudflared → caddy → service)
URLS=(
  "https://auth.grfns.com|Authelia portal"
  "https://watch.grfns.com|Jellyfin (native)"
  "https://read.grfns.com|Komga"
  "https://requests.grfns.com|Jellyseerr"
  "https://media.grfns.com|media-center-ai"
  "https://play.grfns.com|Romm"
)

# Local endpoints (direct, skip cloudflared)
LOCAL_URLS=(
  "http://localhost:7878|Radarr (Mac)"
  "http://localhost:8989|Sonarr (Mac)"
  "http://localhost:5055|Jellyseerr (local)"
  "http://localhost:25600|Komga (local)"
  "http://localhost:9091|Authelia (local)"
  "http://localhost:8096|Jellyfin (native)"
  "http://localhost:8000|media-center-ai (local)"
  "http://localhost:8998|Romm (local)"
  "http://localhost:9999|Stash"
  "http://localhost:6767|Bazarr"
)

failures=()
ok_count=0
fail_count=0

check() {
  local url="$1"
  local label="$2"
  # -k = ignore self-signed certs (Authelia portal sometimes returns its own)
  # Allow 200, 301, 302, 401, 403 (auth-protected = "service is up")
  local code
  code=$(curl -k -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null)

  if [[ "$code" =~ ^(200|301|302|401|403)$ ]]; then
    [[ $QUIET -eq 0 ]] && printf "  ✓  %-32s %s\n" "$label" "($code)"
    ok_count=$((ok_count + 1))
  else
    printf "  ✗  %-32s %s\n" "$label" "(${code:-no response})"
    failures+=("$label ($url) returned ${code:-no response}")
    fail_count=$((fail_count + 1))
  fi
}

[[ $QUIET -eq 0 ]] && echo "Public endpoints (via Cloudflare tunnel):"
for entry in "${URLS[@]}"; do
  check "${entry%%|*}" "${entry##*|}"
done

[[ $QUIET -eq 0 ]] && echo ""
[[ $QUIET -eq 0 ]] && echo "Local endpoints (direct):"
for entry in "${LOCAL_URLS[@]}"; do
  check "${entry%%|*}" "${entry##*|}"
done

# Check the cloudflared process exists
[[ $QUIET -eq 0 ]] && echo ""
[[ $QUIET -eq 0 ]] && echo "Daemons:"
if pgrep -x cloudflared >/dev/null; then
  [[ $QUIET -eq 0 ]] && printf "  ✓  %-32s\n" "cloudflared running"
  ok_count=$((ok_count + 1))
else
  printf "  ✗  %-32s\n" "cloudflared NOT running"
  failures+=("cloudflared daemon not running (pgrep)")
  fail_count=$((fail_count + 1))
fi

# Check Docker is up
if docker info >/dev/null 2>&1; then
  [[ $QUIET -eq 0 ]] && printf "  ✓  %-32s\n" "Docker daemon"
  ok_count=$((ok_count + 1))
else
  printf "  ✗  %-32s\n" "Docker daemon NOT reachable"
  failures+=("Docker daemon unreachable (docker info failed)")
  fail_count=$((fail_count + 1))
fi

[[ $QUIET -eq 0 ]] && echo ""
[[ $QUIET -eq 0 ]] && echo "Summary: $ok_count OK, $fail_count FAIL"

if [[ $fail_count -gt 0 ]]; then
  if [[ $NOTIFY -eq 1 ]]; then
    msg="${#failures[@]} homelab service(s) failing"
    osascript -e "display notification \"$msg\" with title \"Homelab health\" sound name \"Basso\""
  fi
  exit 1
fi

exit 0
