# Calibre Stack Runbook

Two containers: **calibre** (headless library manager, admin via noVNC) +
**calibre-web** (reader UI + OPDS feed for Boox X4 / KOReader).

---

## Quick Reference

| Service       | URL                        | Purpose                        |
|---------------|----------------------------|--------------------------------|
| Calibre noVNC | http://localhost:8090      | Admin GUI — manage library     |
| Calibre-Web   | http://localhost:8083      | Reader UI + OPDS endpoint      |
| Content server| http://localhost:8091      | Calibre built-in content server|

---

## First Boot

```bash
cd ~/docker/calibre
docker compose up -d
```

1. Open **http://localhost:8090** — this is the Calibre desktop via noVNC.
2. In the Calibre app that appears, choose **Change/create library** and point it at `/library`
   (this is the bind-mount for `~/calibre-library`). Calibre will create `metadata.db` there.
3. If you ran the empty-library init one-shot below first, the library already exists — just
   point Calibre at `/library` and it will detect the existing `metadata.db`.

---

## Bulk Import (~81k EPUBs)

In the Calibre noVNC GUI:

1. **Add Books** → "Add books from directories, recursively"
2. Point at `/intake/english_keep` (bind-mounted from `~/Downloads/Epubs/INTAKE/english_keep`)
3. Do it in **chunks of 5,000–10,000 files** — this keeps `metadata.db` write locks manageable
   and lets you see progress. Use the "Add books from a single directory" dialog and navigate
   subdirectories one at a time if the recursive add stalls.
4. After each chunk completes, let Calibre settle (watch the job indicator top-right).

---

## Metadata Fetch (the big quality win)

After import:

1. Select all books (`Ctrl+A`)
2. **Edit metadata** → "Download metadata and covers"
3. Leave overnight — at 81k books this takes many hours.
4. Result: cover images, clean titles/authors, series info, descriptions.

---

## Recommended Plugins

Install via **Preferences → Plugins → Get new plugins**:

- **Find Duplicates** — surfaces content-hash dupes across the library
- **Goodreads Sync** — syncs read/want-to-read status from your Goodreads account
- **Manage Series** — bulk-assign and reorder series metadata

---

## Calibre-Web First-Time Setup

1. Open **http://localhost:8083**
2. When prompted for the database location, enter: `/books/metadata.db`
   (`/books` is the bind-mount for `${LIBRARY_PATH}`)
3. Default login: `admin` / `admin123` — **change this immediately**
4. Under **Admin → Edit User → admin**: set a strong password, add your email.

---

## OPDS for Boox X4 (KOReader)

1. Install **KOReader** on the X4 — it runs well under CrossInk (e-ink optimized).
2. In KOReader: **Search → OPDS catalog → +**
3. Add: `http://<your-mac-hostname-or-ip>:8083/opds`
   (or via Caddy reverse proxy: `https://books.grfns.com/opds`)
4. Browse and download books directly to the device.

---

## Caddy Integration

Point your existing Caddy/Authelia setup at Calibre-Web:

```caddy
books.grfns.com {
    reverse_proxy 127.0.0.1:8083
}
```

Authelia handles authentication upstream; Calibre-Web itself can be left on default auth
or set to "Reverse Proxy" auth mode (Admin → Configuration → Feature Configuration).

---

## Author Normalization

Calibre stores authors however they were embedded in metadata — often inconsistently
("Stephen King" vs "King, Stephen"). Fix via:

**Preferences → Manage authors** — merge variants of the same author.

High-volume authors to check first: Patterson, King, Christie, Roberts, Grisham, Rowling.

---

## Virtual Libraries (killer feature at 80k books)

Virtual libraries let you slice the collection without moving files.

**Tags menu → Virtual library → Create virtual library**

Useful examples:
- `formats:EPUB` — only EPUBs
- `tags:"Science Fiction"` — by genre tag
- `rating:>3` — only rated books
- `series:"#~."` — books that are part of a series
- `authors:"King, Stephen"` — single author

---

## Empty Library Init (optional, run before first `up -d`)

Creates `metadata.db` so Calibre-Web doesn't show an error before any books are imported:

```bash
docker run --rm   -v ~/calibre-library:/library   lscr.io/linuxserver/calibre:latest   /usr/bin/calibredb --library-path=/library list
```

---

## Migration to MediaStorage (later)

When the new MediaStorage drive is ready:

```bash
# 1. Stop the stack
cd ~/docker/calibre
docker compose down

# 2. Move the library
mv ~/calibre-library /Volumes/MediaStorage/Calibre-Library

# 3. Update .env
#    Edit LIBRARY_PATH in ~/docker/calibre/.env:
#    LIBRARY_PATH=/Volumes/MediaStorage/Calibre-Library

# 4. Restart
docker compose up -d
```

Calibre's `metadata.db` stores only relative paths internally — the move is safe, no
path rewriting needed.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Calibre-Web: "db not found" | Make sure Calibre ran first and created `metadata.db`; check `/books/` bind mount |
| noVNC blank / timeout | Container still starting; wait 30s and refresh |
| Port conflict | Check `lsof -i :8083` / `:8090` / `:8091`; 8080 is taken by unpackarr (we avoid it) |
| Container exits immediately | Check `docker logs calibre`; common cause: bad `PUID`/`PGID` or missing config dir |
| Metadata download stalls | Normal at scale; let it run overnight. Check Calibre jobs panel for errors |

