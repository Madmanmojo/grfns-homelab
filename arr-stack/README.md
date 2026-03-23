# Mac Arr Stack (Docker)

Docker Compose setup for Radarr, Sonarr, and Whisparr on Mac to manage library inventory.

## Purpose

- **Seedbox Arr Stack**: Single source of truth - handles searching and downloading
- **Mac Arr Stack**: Verifies files exist on Mac, then updates seedbox Radarr's database
- **No duplication**: Seedbox Radarr is the only one managing downloads

## Setup

1. **Start the stack:**
   ```bash
   cd ~/docker/arr-stack
   docker-compose up -d
   ```

2. **Access the web UIs:**
   - Radarr: http://localhost:7878
   - Sonarr: http://localhost:8989
   - Whisparr: http://localhost:6969

3. **Initial Configuration:**
   - Open each app in browser
   - Go to Settings → General
   - Set root folders:
     - Radarr: `/movies` (maps to `/Volumes/MediaStorage/Movies`)
     - Sonarr: `/tv` (maps to `/Volumes/MediaStorage/TV`)
     - Whisparr: `/adult` (maps to `/Volumes/MediaStorage/Adult`)
   - Get API keys from Settings → General → Security

4. **Sync verified files to seedbox:**
   ```bash
   # First, get Mac Radarr API key and update the script
   # Then trigger library scan in Mac Radarr: System → Tasks → Rescan Library
   # Finally, run sync script:
   python3 ~/scripts/active/seedbox/mac_radarr_to_seedbox_sync.py
   ```
   
   This script:
   - Reads Mac Radarr's verified file list (files that exist)
   - Updates seedbox Radarr's database to mark those files as existing
   - Seedbox Radarr now knows what you have, even though it can't verify Mac paths

## Ports

- **Mac Radarr**: 7878 (seedbox uses 7879 via tunnel)
- **Mac Sonarr**: 8989 (seedbox uses 8990 via tunnel)
- **Mac Whisparr**: 6969 (seedbox uses 6970 via tunnel)

## Volumes

- Config: `./config/{radarr,sonarr,whisparr}` (persistent config)
- Media: `/Volumes/MediaStorage` (read-only access to library)

## Notes

- Volumes are mounted read-only (`:ro`) - Mac Arr stack doesn't download
- Seedbox Arr stack handles all downloads (single source of truth)
- Mac Arr stack verifies files exist, then updates seedbox Radarr's database
- No duplication - seedbox Radarr is the only one managing downloads
- "Wanted > Missing" becomes accurate because seedbox Radarr knows what exists (from Mac verification)

