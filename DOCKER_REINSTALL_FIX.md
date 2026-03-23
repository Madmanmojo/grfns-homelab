# Fix Docker Desktop After Failed Update

## What’s wrong

Docker won’t start and you see **"failed to connect to the docker API"** or **"The application cannot be opened because its executable is missing"**.

- The **Docker daemon isn’t running** because **Docker.app is broken**: the app bundle is missing all `Info.plist` files (likely from a bad or partial update).
- The socket `~/.docker/run/docker.sock` is only created when Docker Desktop starts, so it’s missing when the app can’t launch.

## Fix: Reinstall Docker Desktop

### 1. Close anything using Docker

Quit:

- Terminal windows/tabs that use `docker`
- VS Code / Cursor (or any IDE using Docker)
- Scripts or agents that call Docker

This avoids a partial copy again during install.

### 2. Remove the broken app

In Finder or Terminal:

```bash
# Move Docker.app to Trash (then empty Trash)
rm -rf /Applications/Docker.app
```

Or: drag **Docker.app** from `/Applications` to the Trash, then empty the Trash.

### 3. Download and install again

- **Apple Silicon (M1/M2/M3):**  
  https://desktop.docker.com/mac/main/arm64/Docker.dmg  
- **Intel Mac:**  
  https://desktop.docker.com/mac/main/amd64/Docker.dmg  

Then:

1. Open the DMG.
2. Drag **Docker.app** into **Applications**.
3. Wait until the copy finishes before opening anything that uses Docker.
4. Open **Docker** from Applications and let it finish starting (whale icon in menu bar).

### 4. Restore your settings (optional)

Your config was backed up to:

- `~/.docker/backup-before-reinstall/daemon.json`
- `~/.docker/backup-before-reinstall/config.json`

After Docker Desktop is running again, you can copy them back if you want the same daemon/config:

```bash
cp ~/.docker/backup-before-reinstall/daemon.json ~/.docker/
cp ~/.docker/backup-before-reinstall/config.json ~/.docker/
```

Then restart Docker Desktop from the menu bar.

### 5. Confirm

```bash
docker info
```

You should see daemon info instead of a connection error.

---

**One-liner to open the correct download page (Apple Silicon):**

```bash
open "https://desktop.docker.com/mac/main/arm64/Docker.dmg"
```

(Use the amd64 link above if you’re on Intel.)
