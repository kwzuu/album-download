---
name: album-download
description: Find an album on Soulseek and import it into the user's beets library. Use when asked to download an album, add an album or artist to the library, get "the album that <track> is from", or fetch music off Soulseek. Covers identifying the right MusicBrainz release, downloading with sockseek, and importing with beets.
---

# Album download → beets import

End-to-end: identify the release, pull it off Soulseek, import it tagged. The plumbing is
in scripts; my job is the judgement calls between them.

```
B=~/.claude/skills/album-download/bin
$B/mb-releases "ARTIST" "ALBUM"            # 1. candidate releases + already-in-library check
$B/mb-releases --tracks MBID               #    tracklist (cached for album-check)
$B/slsk preview "ARTIST - ALBUM" COUNT     # 2. what's shared, with extras + slsk:// links
$B/slsk get "slsk://user/folder/" COUNT    # 3. download exactly that folder to staging
$B/album-import STAGED_FOLDER MBID         # 4+5. wrong-album check, import, mirror, verify
```

COUNT is `13` (exact), `12-14` (range: accepts original and remaster editions) or `10+`.
Run `--help` on any of them for details. Downloads take minutes: run `slsk get` in the
background.

## What the scripts already handle (don't redo by hand)

- **Preflight:** sockseek on PATH, Nicotine+ not running (one Soulseek session per account).
- **Credentials:** read at run time from `$SLSK_USERNAME`/`$SLSK_PASSWORD` or else
  `~/.config/nicotine/config`, redacted from all output and logs. Never write them anywhere.
- **Staging:** always `~/Downloads/soulseek` (or `$ALBUM_DOWNLOAD_STAGE`), never the library
  (if Nicotine+'s own `downloaddir` points into the library, that's a trap). `slsk get` refuses `-o`.
- **Two quality passes:** FLAC, then MP3 ≥320 only if FLAC has nothing complete. Never one
  combined filter: `--min-bitrate` drops FLACs whose clients report no bitrate.
- **Wrong-album guard:** `album-import` runs `album-check` first, matching files to the MB
  tracklist by title and length. A folder can pass every sockseek filter and still be a
  different album. Exits 4 on a mismatch; `--no-check` only if you've looked yourself.
- **Silent skips:** `-q` imports that lose to `quiet_fallback: skip` exit 0 with nothing
  imported. `album-import` checks the MBID is really in the library, retries once with `-I`
  (incremental mode remembers skipped paths) and prints the match distance.
- **Mirror art:** if the convert plugin has a `dest`, runs `beets convert -a -y` (auto_keep
  doesn't copy cover art).
- **Verify:** library/mirror track counts and covers, no `.opus` in the library, new `skip`
  lines in import.log, leftover audio in staging.
- **beets** is always run as `python3 -m beets` (`/usr/bin/beet` drops plugins).

If sockseek is missing, run `install.sh` from the album-download repo (it fetches a
self-contained build into `~/.local/bin`, no root or .NET needed).

## The judgement calls

**1. Which release.** If given a track, resolve its album first (web search is fine). Then
pick the **standard digital/CD release**: deluxe/box/USB editions with inflated track counts
are rarely on Soulseek. MB scores every edition 100, so scan the whole list (default 20);
vinyl colour variants can crowd the digital release off a short list. When editions differ
by a few bonus tracks, preview with a range and pin the MBID that matches the folder you
actually get.

**2. Which folder** (from `slsk preview`). Weigh: complete count, format/bit depth, upload
speed + free slot, and extras: filetote imports `.lrc .pdf .nfo .txt .log .cue`, so lyrics
or a CD rip log/cue are worth preferring (a cue/log also says "CD rip": pin a CD release).
Look at the first/last filenames: `A1.`/`B6.` numbering means a vinyl rip; a 60-track
"demos" folder can slip through a `13+` count; scene releases with `_(original_mix)` names
match worse. Then `slsk get` the chosen `slsk://` link, not the search string, so you get
what you judged.

**3. Searching.** If `"ARTIST - ALBUM"` finds nothing, try plain keywords without the dash
(`"glass beach first glass beach album"`): the dash form becomes a stricter
artist/album search and returned 0 where keywords found 110. Titles full of punctuation
(*Burn the Earth! Leave It Behind!*) can miss even as keywords: search the artist alone
with a loose count (`"ARTIST" 3+`) and read the folder names. For generic or self-titled
albums, put the year in the query or you'll get a different album.

**4. Partial or missing.** Don't take a partial silently. Relax the count (`10+`), try the
MP3 pass, or report what's actually available and let the user decide.

**5. A skipped import.** If `album-import` exits 3, read the printed distance. Only if you're
sure the release is right, re-run with `--thresh <distance + 0.01>` (a one-off
`strong_rec_thresh` overlay; the config's 0.45 is a deliberate guard).
`quiet_fallback: asis` is never the fix: it ignores the pinned release.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Login refused | Nicotine+ is running. Close it. |
| Downloads stall or get refused | Some users block peers with no shares (sockseek shares nothing). `slsk get` another link from the preview. |
| .NET stack traces in sockseek output | Peer connection noise. Harmless if the download finished; the scripts ignore it. |
| Album in library but absent from the convert mirror | Already-Opus source (copied, not re-encoded) or an art-only gap. `python3 -m beets convert -a -y mb_albumid:MBID`. |
| Opus files inside the library | `convert.auto` was enabled instead of `auto_keep`; it replaces originals (beetsplug/convert.py:710-736). |

Logs: `~/.cache/album-download/logs/`. Preview JSON (all results, not just the top N):
`~/.cache/album-download/preview-*.json`.

## Don't

- Don't download into the beets library.
- Don't delete staging leftovers that still hold files (sidecars beets doesn't take, older
  runs' folders). Tell the user they're there and let them decide. Empty folders are fine
  to remove (`album-import` does it for its own).
- Don't run `lastgenre` unprompted: it is deliberately `auto: no`. Offer it, then ask.
- Don't run a whole-library `beet convert` backfill unprompted.
- Don't grab a partial album silently.
