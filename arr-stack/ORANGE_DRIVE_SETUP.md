# Moving Docker Data to Orange Drive

## Quick Setup (Arr Stack Config Only)

### Step 1: Run Migration Script

```bash
cd ~/docker/arr-stack
./move_to_orange.sh
```

This will:
- Stop containers
- Create directories on Orange drive
- Move existing config (if any)
- Keep backups

### Step 2: Start Containers

```bash
docker-compose up -d
```

Config is now stored on Orange drive at:
- `/Volumes/Orange/docker/arr-stack/config/radarr`
- `/Volumes/Orange/docker/arr-stack/config/sonarr`
- `/Volumes/Orange/docker/arr-stack/config/whisparr`

---

## Advanced: Move Docker Desktop VM Data (Optional)

This moves the entire Docker VM disk to Orange drive, saving significant space on internal drive.

### Step 1: Quit Docker Desktop

1. Click Docker icon in menu bar
2. Select "Quit Docker Desktop"
3. Wait for it to fully quit

### Step 2: Move VM Data

```bash
# Create directory on Orange
mkdir -p /Volumes/Orange/docker/vm

# Move the VM disk (this is the big file, 60GB+)
mv ~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw \
   /Volumes/Orange/docker/vm/

# Create symlink back
ln -s /Volumes/Orange/docker/vm/Docker.raw \
      ~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw
```

### Step 3: Restart Docker Desktop

1. Open Docker Desktop
2. It should use the VM from Orange drive

### Verification

```bash
# Check symlink
ls -la ~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw

# Should show it points to Orange drive
```

---

## Space Savings

**Arr Stack Config Only:**
- Saves: ~1-5GB (depends on database size)
- Easy to do, low risk

**Docker Desktop VM:**
- Saves: 60-100GB+ (the big win!)
- More complex, but worth it if you need space

---

## Important Notes

1. **Orange Drive Must Be Mounted:**
   - Docker containers won't start if Orange drive isn't mounted
   - Make sure Orange drive auto-mounts on boot

2. **Backup:**
   - Config is backed up during migration
   - Consider backing up Orange drive regularly

3. **Performance:**
   - Thunderbolt 3 is fast enough for Docker
   - Should see minimal performance impact

4. **If Orange Drive Unmounts:**
   - Containers will stop
   - Just remount and restart: `docker-compose up -d`

---

## Troubleshooting

### Containers won't start:
- Check Orange drive is mounted: `ls /Volumes/Orange`
- Check permissions: `ls -la /Volumes/Orange/docker/arr-stack/config/`

### Config missing:
- Check backup: `ls ~/docker/arr-stack/config/*.backup.*`
- Restore if needed

### Docker Desktop won't start after VM move:
- Check symlink: `ls -la ~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw`
- Verify file exists: `ls -lh /Volumes/Orange/docker/vm/Docker.raw`














