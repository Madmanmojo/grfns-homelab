#!/usr/bin/env bash
# Homelab health check — pings each *.grfns.com URL and reports status.
# Exit code: 0 if all healthy, 1 if any failure.
#
# Usage:
#   ./healthcheck.sh                    # human output
#   ./healthcheck.sh --quiet            # only print failures
#   ./healthcheck.sh --notify           # macOS notification + Telegram on failures
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

# Load Telegram credentials from media-center-ai .env (if present)
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
_env_file="/Users/jarvis/media-center-ai/.env"
if [[ -f "$_env_file" ]]; then
  TELEGRAM_BOT_TOKEN=$(grep -m1 '^TELEGRAM_BOT_TOKEN=' "$_env_file" | cut -d= -f2-)
  TELEGRAM_CHAT_ID=$(grep -m1 '^TELEGRAM_CHAT_ID=' "$_env_file" | cut -d= -f2-)
fi

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
# NB: containers bound with `127.0.0.1:port:port` only listen on IPv4 loopback.
# macOS resolves `localhost` to ::1 (IPv6) first, so we use 127.0.0.1 explicitly.
LOCAL_URLS=(
  "http://127.0.0.1:7878|Radarr (Mac)"
  "http://127.0.0.1:8989|Sonarr (Mac)"
  "http://127.0.0.1:5055|Jellyseerr (local)"
  "http://127.0.0.1:25600|Komga (local)"
  "http://127.0.0.1:3801|Komf (local)"
  "http://127.0.0.1:9091|Authelia (local)"
  "http://127.0.0.1:8096|Jellyfin (native)"
  "http://127.0.0.1:8000|media-center-ai (local)"
  "http://127.0.0.1:8998|Romm (local)"
  "http://127.0.0.1:9999|Stash"
  "http://127.0.0.1:6767|Bazarr"
)

failures=()
failure_names=()
ok_count=0
fail_count=0
public_fail_count=0
local_fail_count=0
daemon_fail_count=0

check() {
  local url="$1"
  local label="$2"
  local bucket="$3"  # "public", "local", or "daemon"
  # -k = ignore self-signed certs (Authelia portal sometimes returns its own)
  # Allow 200, 301, 302, 307, 308, 401, 403 (auth-protected = "service is up")
  local code
  code=$(curl -k -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null)

  if [[ "$code" =~ ^(200|301|302|307|308|401|403)$ ]]; then
    [[ $QUIET -eq 0 ]] && printf "  ✓  %-32s %s\n" "$label" "($code)"
    ok_count=$((ok_count + 1))
  else
    printf "  ✗  %-32s %s\n" "$label" "(${code:-no response})"
    failures+=("$label ($url) returned ${code:-no response}")
    failure_names+=("$label")
    fail_count=$((fail_count + 1))
    case "$bucket" in
      public) public_fail_count=$((public_fail_count + 1)) ;;
      local)  local_fail_count=$((local_fail_count + 1)) ;;
      daemon) daemon_fail_count=$((daemon_fail_count + 1)) ;;
    esac
  fi
}

[[ $QUIET -eq 0 ]] && echo "Public endpoints (via Cloudflare tunnel):"
for entry in "${URLS[@]}"; do
  check "${entry%%|*}" "${entry##*|}" "public"
done

[[ $QUIET -eq 0 ]] && echo ""
[[ $QUIET -eq 0 ]] && echo "Local endpoints (direct):"
for entry in "${LOCAL_URLS[@]}"; do
  check "${entry%%|*}" "${entry##*|}" "local"
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
  failure_names+=("cloudflared")
  fail_count=$((fail_count + 1))
  daemon_fail_count=$((daemon_fail_count + 1))
fi

# Check Docker is up
if docker info >/dev/null 2>&1; then
  [[ $QUIET -eq 0 ]] && printf "  ✓  %-32s\n" "Docker daemon"
  ok_count=$((ok_count + 1))
else
  printf "  ✗  %-32s\n" "Docker daemon NOT reachable"
  failures+=("Docker daemon unreachable (docker info failed)")
  failure_names+=("Docker")
  fail_count=$((fail_count + 1))
  daemon_fail_count=$((daemon_fail_count + 1))
fi

# Container resource check — catches a container that's stuck spinning
# (high CPU/memory, climbing toward its limit) while still answering its
# HTTP port fine, so the checks above wouldn't see anything wrong. Real
# incident 2026-08-21: Bazarr sat stuck for ~5 hours with zero new log
# activity while CPU climbed past 100% and memory climbed from 60% to 71%
# of its container limit in about a minute — invisible to every check
# above, found only by manually looking at `docker stats`. Two independent
# signals, either one alone is too noisy: memory near its container limit
# (approaching OOM regardless of trend), or memory climbing fast since the
# last run (state file persists prior mempercent per container to diff
# against — a single high reading can be a normal burst, but a fast
# climb between checks 15 minutes apart is not).
resource_fail_count=0
[[ $QUIET -eq 0 ]] && echo ""
[[ $QUIET -eq 0 ]] && echo "Container resources:"
STATE_FILE="/Users/jarvis/docker/scripts/.container_resource_state"
declare -A prev_mem
if [[ -f "$STATE_FILE" ]]; then
  while IFS='|' read -r cname cmem; do
    prev_mem["$cname"]="$cmem"
  done < "$STATE_FILE"
fi

MEM_LIMIT_ALERT=85    # % of container's own memory limit
MEM_CLIMB_ALERT=15    # percentage-point jump since last check

: > "${STATE_FILE}.tmp"
while IFS='|' read -r cname cmem; do
  cmem_num="${cmem%.*}"
  echo "${cname}|${cmem_num}" >> "${STATE_FILE}.tmp"

  reason=""
  if [[ "$cmem_num" -ge "$MEM_LIMIT_ALERT" ]]; then
    reason="mem ${cmem_num}% of limit"
  elif [[ -n "${prev_mem[$cname]:-}" ]]; then
    delta=$(( cmem_num - prev_mem["$cname"] ))
    if [[ "$delta" -ge "$MEM_CLIMB_ALERT" ]]; then
      reason="mem climbing ${prev_mem[$cname]}%→${cmem_num}%"
    fi
  fi

  if [[ -n "$reason" ]]; then
    printf "  ✗  %-32s %s\n" "$cname" "($reason)"
    failures+=("$cname: $reason")
    failure_names+=("$cname (resource)")
    fail_count=$((fail_count + 1))
    resource_fail_count=$((resource_fail_count + 1))
  else
    [[ $QUIET -eq 0 ]] && printf "  ✓  %-32s %s\n" "$cname" "(mem ${cmem_num}%)"
  fi
done < <(docker stats --no-stream --format '{{.Name}}|{{.MemPerc}}' 2>/dev/null)
mv "${STATE_FILE}.tmp" "$STATE_FILE"
[[ $resource_fail_count -eq 0 ]] && ok_count=$((ok_count + 1))

[[ $QUIET -eq 0 ]] && echo ""
[[ $QUIET -eq 0 ]] && echo "Summary: $ok_count OK, $fail_count FAIL"

if [[ $fail_count -gt 0 ]]; then
  if [[ $NOTIFY -eq 1 ]]; then
    # Build subtitle from short failure names (cap at 5 to avoid overflow)
    names_display=""
    for i in "${!failure_names[@]}"; do
      [[ $i -ge 5 ]] && names_display+=" + $((${#failure_names[@]} - 5)) more" && break
      [[ $i -gt 0 ]] && names_display+=" · "
      names_display+="${failure_names[$i]}"
    done

    # Detect likely Caddy port-bind issue:
    # public endpoints failing, but all locals + daemons healthy
    if [[ $public_fail_count -gt 0 && $local_fail_count -eq 0 && $daemon_fail_count -eq 0 ]]; then
      notif_title="Homelab: $fail_count public endpoint(s) down"
      notif_msg="All local services healthy — likely Caddy port-bind issue. Click to restart Caddy."
      notif_action="cd /Users/jarvis/docker/authelia && /usr/local/bin/docker compose restart caddy"
    else
      notif_title="Homelab: $fail_count service(s) down"
      notif_msg="Click to view healthcheck log"
      notif_action="open -a Console /Users/jarvis/docker/scripts/.healthcheck.log"
    fi

    # Use terminal-notifier if available, fall back to osascript
    tn="$(command -v terminal-notifier || echo /opt/homebrew/bin/terminal-notifier)"
    if [[ -x "$tn" ]]; then
      "$tn" \
        -title "$notif_title" \
        -subtitle "$names_display" \
        -message "$notif_msg" \
        -execute "$notif_action" \
        -sound Basso \
        -sender com.apple.Terminal
    else
      osascript -e "display notification \"$names_display\" with title \"$notif_title\" sound name \"Basso\""
    fi

    # Telegram alert
    if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
      tg_lines=()
      for name in "${failure_names[@]}"; do
        tg_lines+=("  • $name")
      done
      if [[ $public_fail_count -gt 0 && $local_fail_count -eq 0 && $daemon_fail_count -eq 0 ]]; then
        tg_footer="All local services healthy — likely Caddy port-bind issue."
      else
        tg_footer="Check <code>/Users/jarvis/docker/scripts/.healthcheck.log</code> for details."
      fi
      tg_msg="⚠️ <b>Homelab: $fail_count service(s) down</b>
$(printf '%s\n' "${tg_lines[@]}")

$tg_footer"
      curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=${tg_msg}" \
        --data-urlencode "parse_mode=HTML" \
        -o /dev/null
    fi
  fi
  exit 1
fi

exit 0
