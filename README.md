# JARVIS Homelab

Self-hosted media + automation stack running on a Mac mini (`JARVIS`).

## Architecture (the 30-second version)

```
                ┌──────────────────────────────────────┐
   Internet ──> │  Cloudflare Tunnel (cloudflared)     │
                │  *.grfns.com → localhost:80          │
                └──────────────┬───────────────────────┘
                               │
                ┌──────────────▼───────────────────────┐
                │  Caddy (reverse proxy, :80)          │
                │  Routes by hostname, forwards to     │
                │  Authelia for SSO on protected paths │
                └─┬────────────────────────────────────┘
                  │
       ┌──────────┴────────────────────────────────┐
       │                                           │
   Docker stacks                            Native apps
   ─────────────                            ───────────
   • arr-stack (verification)               • Jellyfin.app    :8096
   • komga (comics)                         • Air Video Server HD
   • stash                                  • Syncthing (brew)
   • romm (retro games)
   • authelia (SSO)
   • media-center-ai
```

**Source of truth for downloads is the SEEDBOX** (`10.10.10.1` via VPN) — the Mac stack only verifies what's local and updates the seedbox arr DB.

## Stacks (all in this repo, all `docker compose up -d`-able)

| Stack | Containers | Purpose |
|---|---|---|
| `arr-stack/` | radarr-mac, sonarr-mac, kapowarr, flaresolverr, jellyseerr, bazarr | Library verification, request management, comics download |
| `komga/` | komga, komf | Comics server (OPDS for Panels) + metadata fetcher |
| `stash/` | stash | Adult content manager (with AI plugins) |
| `romm/` | romm, romm-db | Retro game manager (MariaDB backend) |
| `authelia/` | lldap, authelia, caddy | SSO + reverse proxy for everything |

## Service inventory

| Service | Internal port | Local URL | Public URL | Stack | Depends on |
|---|---|---|---|---|---|
| Radarr (Mac) | 7878 | http://localhost:7878 | — | arr-stack | MediaStorage mounted |
| Sonarr (Mac) | 8989 | http://localhost:8989 | — | arr-stack | MediaStorage mounted |
| Kapowarr | 5656 (host 7595) | http://localhost:7595 | — | arr-stack | MediaStorage, ~/.kapowarr |
| FlareSolverr | 8191 | http://localhost:8191 | — | arr-stack | (used by Prowlarr indexers) |
| Jellyseerr | 5055 | http://localhost:5055 | https://requests.grfns.com | arr-stack | seedbox arr APIs |
| Bazarr | 6767 | http://localhost:6767 | — | arr-stack | MediaStorage |
| Komga | 25600 | http://localhost:25600 | https://read.grfns.com | komga | /Volumes/Orange/Comics |
| Komf | 8085 (host 3801) | http://localhost:3801 | — | komga | komga |
| Stash | 9999 | http://localhost:9999 | — | stash | /Volumes/MediaStorage/Adult, Orange/docker/stash/config |
| Romm | 8080 (host 8998) | http://localhost:8998 | https://play.grfns.com | romm | romm-db, MediaStorage/Games |
| LLDAP | 17170 | http://localhost:17170 | — | authelia | (none) |
| Authelia | 9091 | http://localhost:9091 | https://auth.grfns.com | authelia | lldap |
| Caddy | 80 | http://localhost:80 | (the tunnel routes here) | authelia | authelia, all upstream services, Jellyfin native |
| Jellyfin (native) | 8096 | http://localhost:8096 | https://watch.grfns.com | — | `/Applications/Jellyfin.app` |
| media-center-ai | 8000 | http://localhost:8000 | https://media.grfns.com | media-center-ai | sonarr, radarr, jellyfin, komga APIs |

## Cloudflare tunnel routes

Tunnel ID: `8ee747de-1c02-451e-a8d3-a02f69117f63`
Config: `~/.cloudflared/config.yml`
Credentials: `~/.cloudflared/8ee747de-...json` + `~/.cloudflared/cert.pem`

| Subdomain | Routes via Caddy to | Auth |
|---|---|---|
| `auth.grfns.com` | authelia | (the auth portal — public) |
| `watch.grfns.com` | Jellyfin native :8096 | Authelia (API calls bypass) |
| `read.grfns.com` | komga :25600 | Authelia |
| `requests.grfns.com` | jellyseerr :5055 | Authelia |
| `media.grfns.com` | media-center-ai :8000 | Authelia |
| `play.grfns.com` | romm :8998 | Authelia |

## Where things live

| What | Location | Why |
|---|---|---|
| Compose files, scripts, docs | `~/docker/` (this repo) | Version controlled, small, fast to back up |
| Docker VM data (containers, images, volumes) | `/Volumes/Orange/docker/vm/DockerDesktop/Docker.raw` | Big file (~1TB), too large for internal SSD; survives Mac rebuild |
| arr-stack bind-mount configs | `/Volumes/Orange/docker/arr-stack/config/{radarr,sonarr,jellyseerr}/` | Live state, on Orange (out of TM noise) |
| Stash bind-mount config | `/Volumes/Orange/docker/stash/config/` | Live state |
| Komga config + data | `~/.komga/{config,data}/` | Internal SSD (small, fast access) |
| Komf config | `~/.komf/` | Internal SSD |
| Kapowarr DB | `~/.kapowarr/` | Internal SSD |
| Romm DB + assets | `~/docker/romm/{db,assets,config,logs}/` | Internal, gitignored |
| Authelia config | `~/docker/authelia/config/` | Internal, gitignored (contains user data) |
| Comics library | `/Volumes/Orange/Comics/` | Big external |
| Movies library | `/Volumes/MediaStorage/Movies/` | QNAP enclosure (4 TB) |
| TV library | `/Volumes/MediaStorage/TV/` | QNAP enclosure |
| Games (ROMs) | `/Volumes/MediaStorage/Games/` | QNAP enclosure |
| Syncthing inbox | `/Volumes/MediaStorage/syncthing-incoming/` | QNAP, where seedbox drops files |

## Boot order (the order things need to be up to work end-to-end)

1. **Drives mounted**: `/Volumes/Orange`, `/Volumes/MediaStorage`. (macOS handles this on login.)
2. **Docker Desktop running**: starts the VM from Orange, which auto-starts containers (`restart: unless-stopped`).
3. **Jellyfin.app running**: needed for `watch.grfns.com` (Caddy points at host:8096).
4. **cloudflared running**: makes `*.grfns.com` reachable from the internet.
5. **Air Video Server HD**: optional, for AVHD clients.
6. **Syncthing**: needed for seedbox → Mac sync.
7. **Seedbox VPN tunnel** (via `~/Projects/media-automation/active/seedbox/Launch_Tunnel_Menubar.app`): needed for the Mac arr stack to talk to the seedbox SABnzbd / arr APIs.

## Common operations

**Bring up a stack** — `cd <stack> && docker compose up -d`
**Tear down a stack** — `cd <stack> && docker compose down`
**Check status** — `docker compose ps` (in any stack dir) or open Docker Desktop
**Tail logs** — `docker compose logs -f <service>`
**Update images** — `docker compose pull && docker compose up -d`

## See also

- [`REBUILD.md`](./REBUILD.md) — what to do after a system rebuild / drive swap
- [`DOCKER_REINSTALL_FIX.md`](./DOCKER_REINSTALL_FIX.md) — what to do if Docker.app itself breaks (different from rebuild scenario)
- [`arr-stack/ORANGE_DRIVE_SETUP.md`](./arr-stack/ORANGE_DRIVE_SETUP.md) — original Docker→Orange migration notes
- [`arr-stack/SETUP_GUIDE.md`](./arr-stack/SETUP_GUIDE.md) — Mac arr stack + Jellyseerr first-time setup
- [`scripts/healthcheck.sh`](./scripts/healthcheck.sh) — pings all `*.grfns.com` URLs
