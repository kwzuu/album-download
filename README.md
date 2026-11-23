# album-download

A [Claude Code](https://claude.com/claude-code) skill that finds an album on Soulseek and
imports it into your [beets](https://beets.io/) library, tagged against the exact
MusicBrainz release. The scripts handle the plumbing and the guardrails. Claude makes the
judgement calls: which edition to pin, and which shared folder to take.

```
bin/mb-releases "ARTIST" "ALBUM"           # candidate releases, and whether you already have it
bin/mb-releases --tracks MBID              # one release's tracklist
bin/slsk preview "ARTIST - ALBUM" 12-14    # shared folders with that many tracks, best first
bin/slsk get "slsk://user/folder/" 12-14   # download exactly that folder to staging
bin/album-import STAGED_FOLDER MBID        # check it's the right album, import, verify
```

The scripts work without Claude too. Run any of them with `--help`.

## Dependencies

- **Python 3.10+** runs the scripts (standard library only, plus what beets brings).
- **[beets](https://beets.io/) 2.x**, importable by `python3`, tags the files and moves
  them into your library. It also brings **mutagen**, which reads tags and track lengths
  for the wrong-album check, and **PyYAML**, which reads beets' config.
  - the `musicbrainz` plugin looks up releases (beets 2.x needs it listed in `plugins`)
  - `fetchart` (recommended) fetches cover art. Without it, the final check reports
    "no cover".
  - `filetote` (optional) brings lyrics, cue sheets and rip logs along with the audio
  - `convert` (optional): if it has a `dest`, the album is also mirrored there, and the
    mirror is checked too. Use `auto_keep: yes`, not `auto: yes`, which replaces your
    originals.
- **[sockseek](https://github.com/fiso64/slsk-batchdl)** is the command-line Soulseek
  client that searches and downloads. `install.sh` installs a self-contained build.
- **A Soulseek account**: set `SLSK_USERNAME` and `SLSK_PASSWORD`, or log in once with
  [Nicotine+](https://nicotine-plus.org/) and the scripts read its config. Close Nicotine+
  while downloading: Soulseek allows only one session per account.
- **pgrep** (procps) checks that Nicotine+ isn't running.
- **Claude Code** runs the skill (optional).

## Install

```
git clone https://github.com/kwzuu/album-download
cd album-download
./install.sh            # or ./install.sh --link to symlink this checkout
```

The script checks the dependencies above, installs sockseek 3.0.5 to `~/.local/bin` if
it's missing (Linux x64 and macOS), and copies the skill to `~/.claude/skills/album-download`
(override with `CLAUDE_SKILLS_DIR`). If something is already installed there, it gets
moved aside, not deleted.

## Configuration

| Variable | Default | |
|---|---|---|
| `ALBUM_DOWNLOAD_STAGE` | `~/Downloads/soulseek` | where downloads go before import (never your library) |
| `SLSK_USERNAME`, `SLSK_PASSWORD` | Nicotine+ config | Soulseek login, redacted from all output |

The library, mirror and import log paths come from `beet config`. Logs and cached
search results are in `~/.cache/album-download/`.

## License

AGPL-3.0-or-later
