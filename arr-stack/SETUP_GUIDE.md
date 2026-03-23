# Complete Setup Guide: Mac Docker Arr Stack + Jellyseerr

## Part 1: Mac Docker Arr Stack Setup

### Step 1: Verify Containers Are Running

```bash
cd ~/docker/arr-stack
docker-compose ps
```

You should see:
- `radarr-mac` - Up
- `sonarr-mac` - Up
- `whisparr-mac` - (optional, had registry issues)

### Step 2: Configure Radarr (Mac)

1. **Open Radarr:**
   - Browser: http://localhost:7878
   - First-time setup wizard will appear

2. **Complete Setup Wizard:**
   - **Username/Password:** Set admin credentials (or skip if you want)
   - **Language:** English
   - **Root Folder:** Click "Add Root Folder"
     - **Path:** `/movies`
     - This maps to `/Volumes/MediaStorage/Movies` on your Mac
   - **Quality Profile:** Choose your preferred quality (e.g., "HD-1080p")
   - **Metadata:** Configure if desired (optional)
   - Click "Save and Continue"

3. **Get API Key:**
   - Go to: **Settings → General → Security**
   - Copy the **API Key** (you'll need this for the sync script)

### Step 3: Configure Sonarr (Mac)

1. **Open Sonarr:**
   - Browser: http://localhost:8989
   - First-time setup wizard will appear

2. **Complete Setup Wizard:**
   - **Username/Password:** Set admin credentials (or skip)
   - **Language:** English
   - **Root Folder:** Click "Add Root Folder"
     - **Path:** `/tv`
     - This maps to `/Volumes/MediaStorage/TV` on your Mac
   - **Quality Profile:** Choose your preferred quality
   - **Metadata:** Configure if desired (optional)
   - Click "Save and Continue"

3. **Get API Key:**
   - Go to: **Settings → General → Security**
   - Copy the **API Key** (for future use if needed)

### Step 4: Configure Whisparr (Mac) - Optional

If Whisparr container is running:

1. **Open Whisparr:**
   - Browser: http://localhost:6969
   - Complete setup wizard similar to above
   - **Root Folder:** `/adult` (maps to `/Volumes/MediaStorage/Adult`)

### Step 5: Scan Libraries in Mac Arr Stack

**For Radarr:**
1. Go to: **System → Tasks**
2. Click **"Rescan Library"**
3. Wait for it to complete (may take a while for large libraries)

**For Sonarr:**
1. Go to: **System → Tasks**
2. Click **"Rescan Library"**

**For Whisparr (if configured):**
1. Go to: **System → Tasks**
2. Click **"Rescan Library"**

### Step 6: Configure Sync Script

1. **Edit the sync script:**
   ```bash
   nano ~/scripts/active/seedbox/mac_radarr_to_seedbox_sync.py
   ```

2. **Find this line (around line 15):**
   ```python
   MAC_RADARR_API_KEY = ""
   ```

3. **Replace with your Mac Radarr API key:**
   ```python
   MAC_RADARR_API_KEY = "your-api-key-here"
   ```

4. **Save and exit** (Ctrl+X, then Y, then Enter)

### Step 7: Test the Sync Script

```bash
python3 ~/scripts/active/seedbox/mac_radarr_to_seedbox_sync.py
```

**Expected output:**
- Should show movies being synced from Mac Radarr to seedbox Radarr
- Check seedbox Radarr to verify movies now show `hasFile=True`

### Step 8: Enable Automatic Sync (Optional)

```bash
launchctl load ~/Library/LaunchAgents/com.jarvis.macradarrsync.plist
```

This will run the sync every hour automatically.

**To check if it's loaded:**
```bash
launchctl list | grep macradarrsync
```

**To unload (if needed):**
```bash
launchctl unload ~/Library/LaunchAgents/com.jarvis.macradarrsync.plist
```

---

## Part 2: Jellyseerr Setup

### Step 1: Create Jellyseerr Docker Compose

Create a new docker-compose file for Jellyseerr:

```bash
mkdir -p ~/docker/jellyseerr
cd ~/docker/jellyseerr
```

### Step 2: Create docker-compose.yml

Create `docker-compose.yml` with:

```yaml
services:
  jellyseerr:
    image: fallenbagel/jellyseerr:latest
    container_name: jellyseerr
    environment:
      - PUID=501
      - PGID=20
      - TZ=America/New_York
      - LOG_LEVEL=info
    volumes:
      - ./config:/app/config
    ports:
      - "5055:5055"  # Jellyseerr web UI
    restart: unless-stopped
```

### Step 3: Start Jellyseerr

```bash
cd ~/docker/jellyseerr
docker-compose up -d
```

Wait 30-60 seconds for initialization.

### Step 4: Access Jellyseerr

1. **Open Jellyseerr:**
   - Browser: http://localhost:5055
   - First-time setup wizard will appear

2. **Complete Initial Setup:**
   - **Create Admin Account:** Set username, email, password
   - Click "Next"

### Step 5: Configure Radarr Connection

1. **Add Service:**
   - Click **"Add Service"** or **"Add Radarr"**
   - **Service Name:** "Seedbox Radarr" (or any name)
   - **Service Type:** Radarr
   - **Server URL:** 
     - If using SSH tunnel: `http://localhost:7879`
     - If direct access: `http://seedbox-ip:7878`
   - **API Key:** 
     - Get from seedbox Radarr: Settings → General → Security
     - Paste the API key
   - **Quality Profile:** Select your preferred profile
   - **Root Folder:** Select the root folder (seedbox path, e.g., `/media/Movies`)
   - Click **"Test Connection"** - should show "Connection successful"
   - Click **"Add Service"**

### Step 6: Configure Sonarr Connection (if using)

1. **Add Service:**
   - Click **"Add Service"** → **"Add Sonarr"**
   - **Service Name:** "Seedbox Sonarr"
   - **Server URL:** 
     - SSH tunnel: `http://localhost:8990`
     - Direct: `http://seedbox-ip:8989`
   - **API Key:** From seedbox Sonarr
   - **Root Folder:** Seedbox path (e.g., `/media/TV`)
   - Click **"Test Connection"**
   - Click **"Add Service"**

### Step 7: Configure Whisparr Connection (if using)

Similar to above, but:
- **Service Type:** Whisparr
- **Server URL:** `http://localhost:6970` (via tunnel) or direct
- **API Key:** From seedbox Whisparr

### Step 8: Configure Jellyseerr Settings

1. **Go to Settings:**
   - Click gear icon (top right) → **Settings**

2. **General Settings:**
   - **Application Title:** Your choice
   - **Application URL:** `http://localhost:5055` (or your domain if using)
   - **Enable Local Login:** Yes (if you want local accounts)
   - **Enable Plex OAuth:** Optional (if using Plex)

3. **Notifications:** Configure if desired

4. **Save Settings**

### Step 9: Verify Everything Works

1. **Test Movie Request:**
   - Search for a movie in Jellyseerr
   - Click "Request"
   - Check seedbox Radarr - movie should appear
   - Check that it's monitored and will download

2. **Check Library Sync:**
   - Jellyseerr should show movies from seedbox Radarr
   - Since we're syncing Mac Radarr → seedbox Radarr, availability should be accurate
   - Run the sync script first if needed:
     ```bash
     python3 ~/scripts/active/seedbox/mac_radarr_to_seedbox_sync.py
     ```

### Step 10: (Optional) Set Up Users

1. **Go to Settings → Users**
2. **Add Users:**
   - Click "Add User"
   - Enter email/username
   - Set permissions (Admin, User, etc.)
   - Users can request content through Jellyseerr

---

## Verification Checklist

### Mac Arr Stack:
- [ ] Radarr accessible at http://localhost:7878
- [ ] Radarr root folder set to `/movies`
- [ ] Radarr API key copied
- [ ] Radarr library scan completed
- [ ] Sonarr accessible at http://localhost:8989
- [ ] Sonarr root folder set to `/tv`
- [ ] Sonarr library scan completed
- [ ] Sync script API key configured
- [ ] Sync script tested successfully
- [ ] Automatic sync enabled (optional)

### Jellyseerr:
- [ ] Jellyseerr accessible at http://localhost:5055
- [ ] Admin account created
- [ ] Seedbox Radarr connected and tested
- [ ] Seedbox Sonarr connected (if using)
- [ ] Seedbox Whisparr connected (if using)
- [ ] Test request works
- [ ] Library shows accurate availability

---

## Troubleshooting

### Mac Radarr can't see files:
- Check root folder is set to `/movies` (not `/Volumes/MediaStorage/Movies`)
- Verify volume mount in docker-compose.yml
- Check Docker has Full Disk Access (System Settings → Privacy)

### Sync script fails:
- Verify Mac Radarr API key is correct
- Check Mac Radarr has scanned library first
- Verify seedbox Radarr is accessible via tunnel

### Jellyseerr can't connect to Radarr:
- Verify SSH tunnel is running (if using tunnel)
- Check API key is correct
- Test connection from Jellyseerr settings

### Jellyseerr shows wrong availability:
- Run sync script: `python3 ~/scripts/active/seedbox/mac_radarr_to_seedbox_sync.py`
- Wait a few minutes for sync to complete
- Refresh Jellyseerr

---

## Quick Reference

**URLs:**
- Mac Radarr: http://localhost:7878
- Mac Sonarr: http://localhost:8989
- Mac Whisparr: http://localhost:6969
- Jellyseerr: http://localhost:5055
- Seedbox Radarr (via tunnel): http://localhost:7879
- Seedbox Sonarr (via tunnel): http://localhost:8990

**Important Scripts:**
- Sync script: `~/scripts/active/seedbox/mac_radarr_to_seedbox_sync.py`
- Run sync: `python3 ~/scripts/active/seedbox/mac_radarr_to_seedbox_sync.py`

**Docker Commands:**
- Start: `cd ~/docker/arr-stack && docker-compose up -d`
- Stop: `cd ~/docker/arr-stack && docker-compose down`
- Logs: `cd ~/docker/arr-stack && docker-compose logs -f`














