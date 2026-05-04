# System Rebuild Runbook

What to do after replacing the Mac's internal drive, doing a fresh macOS install, or restoring from Time Machine.

> **The lesson from 2026-05-04**: Time Machine **does not back up Docker.raw** (Docker excludes its own VM disk by default). Your containers and images are NOT in TM. The reason this stack is recoverable is because the VM lives on Orange (`/Volumes/Orange/docker/vm/DockerDesktop/Docker.raw`), which survives Mac rebuilds.

## Prerequisites

- macOS reinstalled, signed in as `jarvis`
- All external drives mounted: Orange, MediaStorage, Big Silver
- Homebrew installed (it should survive TM restore; if not, `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`)
- Docker Desktop installed fresh from https://desktop.docker.com/mac/main/arm64/Docker.dmg (drag to /Applications)
- This repo cloned to `~/docker/` from GitHub

## The rebuild — step by step

### 1. Re-attach the existing Docker VM

After installing Docker Desktop, **DO NOT open it yet.** First, replace the new empty VM disk with a symlink to the one on Orange.

```bash
# Confirm the Orange Docker.raw is there
ls -lh /Volumes/Orange/docker/vm/DockerDesktop/Docker.raw

# Quit Docker Desktop if you accidentally opened it (menu bar → Quit Docker Desktop, wait for whale icon to vanish)

# Remove the empty new Docker.raw and symlink to Orange
rm "/Users/jarvis/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw"
ln -s "/Volumes/Orange/docker/vm/DockerDesktop/Docker.raw" \
      "/Users/jarvis/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw"

# Verify
ls -la "/Users/jarvis/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw"
# Should show: Docker.raw -> /Volumes/Orange/docker/vm/DockerDesktop/Docker.raw
```

> **DO NOT** use Docker Desktop's "Disk image location" UI to point at Orange — it triggers a "Move disk image?" dialog that will overwrite your existing 1 TB Docker.raw with the empty new one. Use the symlink approach above. (This is also documented in `arr-stack/ORANGE_DRIVE_SETUP.md`.)

### 2. Start Docker Desktop

Open Docker Desktop from Applications. The whale icon appears in menu bar. After ~30 seconds, all containers from the old VM should appear in the Containers tab — most will be "Running" because of `restart: unless-stopped`.

**Sanity check:**
```bash
docker ps | wc -l    # should be ~16-20
docker images | wc -l  # should be many
```

If containers DIDN'T come back: the symlink didn't take, or Docker version changed too much. Check `~/Library/Containers/com.docker.docker/Data/log/host/com.docker.backend.log` for errors.

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

### 5. Bring up the seedbox tunnel

The Mac arr stack needs to reach the seedbox at `10.10.10.1` (VPN address).

- Open `~/Projects/media-automation/active/seedbox/Launch_Tunnel_Menubar.app`
- Or run `~/Projects/media-automation/active/seedbox/start_tunnels.sh` directly

### 6. Verify end-to-end

The single most useful check — open `https://watch.grfns.com` in any browser:

- **Authelia login appears, login works, Jellyfin loads** → the entire chain is working (cloudflared + caddy + authelia + Jellyfin native + docker network)
- **Authelia login appears but next step 502s** → cloudflared + auth fine, but a service is down. Check `docker ps` and Jellyfin.app.
- **DNS error / connection refused** → cloudflared isn't running. See step 3.

Then spot-check the others:
- `https://requests.grfns.com` → Jellyseerr
- `https://read.grfns.com` → Komga
- `https://play.grfns.com` → Romm
- `https://media.grfns.com` → media-center-ai

### 7. Run the health check

```bash
~/docker/scripts/healthcheck.sh
```

Should print all green. If any fail, troubleshoot that one service.

## Common rebuild issues

**"Docker shows empty containers list"** → symlink wasn't created or Docker started before the symlink existed. Quit Docker, redo step 1.

**"Containers running but `*.grfns.com` doesn't resolve"** → cloudflared isn't running. `pgrep cloudflared` to check; restart with `sudo launchctl start com.cloudflare.cloudflared`.

**"watch.grfns.com gives 502"** → Jellyfin.app isn't running. Open it.

**"requests.grfns.com gives 502 but Caddy and Authelia are up"** → Jellyseerr container is down. `docker compose -f arr-stack/docker-compose.yml up -d jellyseerr`.

**"All `*.grfns.com` give Authelia 'something went wrong' page"** → Authelia container isn't healthy or LLDAP is down. Check `docker logs authelia` and `docker logs lldap`.

**".env file missing for a stack"** → Restore secrets from your password manager and recreate from `.env.example` template in each stack.

## What NOT to do

- ❌ Don't trust Time Machine alone for Docker. It excludes Docker.raw.
- ❌ Don't use Docker Desktop's UI to change "Disk image location" when an existing VM is at the destination. Use the symlink approach.
- ❌ Don't `rm -rf ~/docker/*/config/` thinking they're stale — those bind-mount dirs ARE the live service state.
- ❌ Don't commit `.env` files to git. Use `.env.example` templates.
