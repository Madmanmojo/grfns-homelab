# Komga (comics server)

Comics library is mounted from **/Volumes/Orange/Comics** → `/comics` in the container.

## First time: switch from Big Silver to Orange

Your current Komga container is still using **Big Silver**. To use **Orange** instead:

1. **Stop and remove the existing container** (Komga config and DB in `~/.komga` are kept):
   ```bash
   docker stop komga
   docker rm komga
   ```

2. **Start Komga with the new compose** (from this directory):
   ```bash
   cd /Users/jarvis/docker/komga
   docker compose up -d
   ```

3. In Komga (http://localhost:25600): **Settings → Libraries**
   - If the old library pointed at `/comics`, it will now see Orange.
   - If you had a library path for Big Silver, edit it to **/comics** (the mount is now Orange).
   - Run a **scan** on the library.

## Optional

- Remove the **import** volume from `docker-compose.yml` if you don’t use that folder.
- Start: `docker compose up -d`
- Stop: `docker compose down`
- Logs: `docker compose logs -f komga`
