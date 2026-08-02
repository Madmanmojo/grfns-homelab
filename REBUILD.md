# System Rebuild Runbook

What to do after replacing the Mac's internal drive, doing a fresh macOS install, or restoring from Time Machine.

> **Docker VM is now on the internal 1 TB drive** (as of 2026-05-13, migrated from Orange). Time Machine **does not back up Docker.raw** (Docker excludes it by default). Containers and images are NOT in TM. This is fine — all configs are bind-mounted to `~/docker/*/` which IS backed up. After a rebuild, just install Docker Desktop fresh and `docker compose up -d` to re-pull images and start.

## Prerequisites

- macOS reinstalled, signed in as `jarvis`
- MediaStorage mounted (required for TV/Movies/Comics/Games volumes)
- Homebrew installed (it should survive TM restore; if not, `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`)
- Docker Desktop installed fresh from https://desktop.docker.com/mac/main/arm64/Docker.dmg (drag to /Applications)
- This repo cloned to `~/docker/` from GitHub

## The rebuild — step by step

### 1. Start Docker Desktop

Open Docker Desktop from Applications. The whale icon appears in the menu bar. Docker will create a fresh VM on the internal drive automatically — no symlink needed.

After ~30 seconds Docker is ready. All images need to be re-pulled (step 2), but all config is in `~/docker/*/` via bind mounts so nothing is lost.

### 2. Pull images and bring up all stacks

```bash
# Pull all images and start each stack
for stack in arr-stack stash romm komga authelia; do
  echo "=== $stack ==="
  cd ~/docker/$stack && docker compose pull && docker compose up -d
done
```

**Sanity check:**
```bash
docker ps --format "{{.Names}}\t{{.Status}}"  # all should be "Up"
```

### 3. Install and start native services

#### cloudflared (the public tunnel)
```bash
which cloudflared || brew install cloudflared
# Config + tunnel credentials should already be at ~/.cloudflared/ (TM-restored)
ls ~/.cloudflared/  # should contain: cert.pem, <tunnel-id>.json, config.yml

# Run as a launchd service (recommended) — runs at boot
sudo cloudflared service install
sudo launchctl start com.cloudflare.cloudflared

# OR run manually for testing
cloudflared tunnel run
```

#### Jellyfin
- Open `/Applications/Jellyfin.app`
- It auto-starts on login (verify in System Settings → General → Login Items)

#### Air Video Server HD
- Open `/Applications/Air Video Server HD.app`
- Should also auto-start on login

#### Syncthing
```bash
which syncthing || brew install syncthing
brew services start syncthing
```

### 4. Re-link LaunchAgents

Some custom launchd jobs may not survive the rebuild (`~/Library/LaunchAgents/` is sometimes missed). Check and re-load:

```bash
ls ~/Library/LaunchAgents/
# Look for: com.jarvis.macradarrsync.plist (and any others you had)

# If missing, recreate from the plist source in this repo (TODO: check in plist sources)
# Then load:
launchctl load ~/Library/LaunchAgents/com.jarvis.macradarrsync.plist
```

### 5. media-center-ai (the dashboard)

Not a `~/docker` stack — it's its own repo, run bare-metal via launchd (not Docker), at `~/Projects/media-center-ai`.

```bash
# Clone
git clone https://github.com/Madmanmojo/media-center-ai.git ~/Projects/media-center-ai
cd ~/Projects/media-center-ai
git checkout main   # dev is the integration branch — check it too if the old Mac is
                     # still reachable, it may have unmerged work worth pulling over first

# Symlink — the Claude Code MCP server registration (~/.claude/settings.json,
# entry "media-center-ai") points at ~/media-center-ai, not ~/Projects/media-center-ai
ln -s ~/Projects/media-center-ai ~/media-center-ai

# venv + deps
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Secrets — same as any other stack's .env
cp .env.example .env
# Fill in from your password manager: TMDB, Sonarr, Radarr, Jellyfin, SABnzbd,
# Komga, OMDb, Prowlarr, Audiobookshelf, Stash, qBittorrent, Syncthing (x2 —
# native Mac instance + the seedbox's), Telegram bot token/chat id.
```

**Restore the databases.** Unlike everything above, this app's state isn't in git — it's two SQLite files at `~/.media-center-ai/` (`media_library.db`, `scheduler.db`), backed up only by Time Machine.

- If TM restored `~/.media-center-ai/` intact: nothing else to do, skip ahead.
- If it's genuinely gone (TM also lost, e.g. drive replaced with no TM restore): the app recreates empty tables on next startup automatically (`database.py`/`scheduler.py`'s `_initialize_database()`), so it won't crash — but historical duplicate-scan groups, quality-audit history, and scheduled-task run counts are gone for good. The actual media library metadata isn't lost, though: run a fresh `scan_library` (dashboard or MCP tool) to repopulate `episodes`/`movies` from what's really on `/Volumes/MediaStorage`. This has happened before — see `~/.media-center-ai/media_library.db.corrupted_backup` + `recovered_data.sql` from the January 2026 corruption incident if you need a reference for what hand-recovery looked like.

**Launchd:**
```bash
# Same caveat as step 4 — LaunchAgents sometimes don't survive a TM restore.
# If missing, copy the tracked source of truth from the repo — do NOT
# hand-recreate this one. It carries EnvironmentVariables (PATH,
# PYTHONUNBUFFERED) that are load-bearing, not cosmetic: without PATH
# including /opt/homebrew/bin, any subprocess call that shells out to a
# Homebrew tool (e.g. ffmpeg, used by Jarvis's voice-note transcription)
# fails with FileNotFoundError — this happened for real on 2026-08-02,
# worked fine in every interactive terminal test, only broke under
# launchd because launchd's default PATH is just /usr/bin:/bin:/usr/sbin:
# /sbin. Without PYTHONUNBUFFERED, stdout is block-buffered when
# redirected to the log file, so print()-based error messages can sit
# invisible for a long time — actively hid the root cause of that same
# incident until it was set.
cp ~/Projects/media-center-ai/launchd/com.jarvis.media-center-ai.plist ~/Library/LaunchAgents/
launchctl load -w ~/Library/LaunchAgents/com.jarvis.media-center-ai.plist
# NB: `launchctl bootstrap` failed with a transient "Input/output error"
# during initial testing, immediately after `bootout` on this exact plist,
# even though the file was valid (plutil -lint passed) and nothing else
# was running on port 8000. `launchctl load -w` (the older API) worked on
# the first try both times this was hit. If bootstrap fails here, don't
# assume the plist is broken — try `load -w` instead before debugging further.
```

**Verify:**
```bash
curl -s http://localhost:8000/api/health
cd ~/Projects/media-center-ai && make test   # 7 tests, should all pass
```

### 6. Bring up the seedbox tunnel

The Mac arr stack needs to reach the seedbox at `10.10.10.1` (VPN address).

- Open `~/Projects/media-automation/active/seedbox/Launch_Tunnel_Menubar.app`
- Or run `~/Projects/media-automation/active/seedbox/start_tunnels.sh` directly

### 7. Verify end-to-end

The single most useful check — open `https://watch.grfns.com` in any browser:

- **Authelia login appears, login works, Jellyfin loads** → the entire chain is working (cloudflared + caddy + authelia + Jellyfin native + docker network)
- **Authelia login appears but next step 502s** → cloudflared + auth fine, but a service is down. Check `docker ps` and Jellyfin.app.
- **DNS error / connection refused** → cloudflared isn't running. See step 3.

Then spot-check the others:
- `https://requests.grfns.com` → Jellyseerr
- `https://read.grfns.com` → Komga
- `https://play.grfns.com` → Romm
- `https://media.grfns.com` → media-center-ai

### 8. Run the health check

```bash
~/docker/scripts/healthcheck.sh
```

Should print all green. If any fail, troubleshoot that one service.

## Common rebuild issues

**"Docker shows empty containers list"** → normal after a fresh install. Run step 2 to pull images and bring stacks up.

**"Containers running but `*.grfns.com` doesn't resolve"** → cloudflared isn't running. `pgrep cloudflared` to check; restart with `sudo launchctl start com.cloudflare.cloudflared`.

**"watch.grfns.com gives 502"** → Jellyfin.app isn't running. Open it.

**"requests.grfns.com gives 502 but Caddy and Authelia are up"** → Jellyseerr container is down. `docker compose -f arr-stack/docker-compose.yml up -d jellyseerr`.

**"All `*.grfns.com` give Authelia 'something went wrong' page"** → Authelia container isn't healthy or LLDAP is down. Check `docker logs authelia` and `docker logs lldap`.

**".env file missing for a stack"** → Restore secrets from your password manager and recreate from `.env.example` template in each stack.

**"media.grfns.com gives 502"** → media-center-ai's launchd service isn't running, or port 8000 isn't bound. `launchctl list | grep media-center-ai` to check; `curl localhost:8000/api/health` to confirm the app itself is even up before blaming the tunnel.

**"media-center-ai starts but the dashboard shows no library data"** → `~/.media-center-ai/media_library.db` is missing or empty (didn't survive the rebuild). See step 5 — run a fresh library scan to repopulate it; historical scan/duplicate-audit records won't come back, but current media on disk will.

## What NOT to do

- ❌ Don't trust Time Machine alone for Docker images — Docker.raw is excluded from TM. Re-pull images on rebuild.
- ❌ Don't use Docker Desktop's UI to change "Disk image location" — it triggers a destructive overwrite. The default location on internal is correct.
- ❌ Don't `rm -rf ~/docker/*/data/` or `~/docker/*/config/` thinking they're stale — those bind-mount dirs ARE the live service state.
- ❌ Don't commit `.env` files to git. Use `.env.example` templates.
- ❌ Don't assume `~/.media-center-ai/` is disposable cache and skip restoring it — `media_library.db`/`scheduler.db` there are the app's actual state, not in git, and only exist via Time Machine.
