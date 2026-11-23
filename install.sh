#!/usr/bin/env bash
# Install the album-download skill for Claude Code, and sockseek if it's missing.
#
#   ./install.sh          copy the skill into ~/.claude/skills/album-download
#   ./install.sh --link   symlink it instead (edits in this checkout take effect)
#
# CLAUDE_SKILLS_DIR overrides ~/.claude/skills. An existing install that isn't
# already ours is moved aside to album-download.bak-<time>, never deleted.
set -euo pipefail

SOCKSEEK_VERSION=3.0.5
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
skills=${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}
dest=$skills/album-download
link=no
case "${1:-}" in
  --link) link=yes ;;
  "") ;;
  *) sed -n '2,8p' "$0"; exit 2 ;;
esac

ok()   { printf '  ok    %s\n' "$*"; }
warn() { printf '  WARN  %s\n' "$*"; }
fail() { printf '  FAIL  %s\n' "$*"; missing=yes; }
missing=no

echo "checking dependencies"
if python3 -c 'import sys; sys.exit(sys.version_info < (3, 10))' 2>/dev/null; then
  ok "python3 $(python3 -c 'import platform; print(platform.python_version())')"
else
  fail "python3 3.10+ not found"
fi
if python3 -c 'import beets, mutagen, yaml' 2>/dev/null; then
  ok "beets $(python3 -c 'import beets; print(beets.__version__)') (importable by python3)"
  plugins=$(python3 -m beets config 2>/dev/null | sed -n 's/^plugins: *//p')
  for p in musicbrainz fetchart; do
    [[ " $plugins " == *" $p "* ]] || warn "beets plugin '$p' isn't enabled (see README)"
  done
else
  fail "beets isn't importable by python3: python3 -m pip install --user beets"
fi
command -v pgrep >/dev/null || fail "pgrep not found (procps)"

if command -v sockseek >/dev/null; then
  ok "sockseek at $(command -v sockseek)"
else
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) plat=linux-x64 ;;
    Darwin-arm64) plat=osx-arm64 ;;
    Darwin-x86_64) plat=osx-x64 ;;
    *) plat= ;;
  esac
  if [[ -z $plat ]]; then
    fail "sockseek not found and no prebuilt for $(uname -sm): https://github.com/fiso64/slsk-batchdl/releases"
  else
    echo "  ...   installing sockseek $SOCKSEEK_VERSION ($plat) into ~/.local/bin"
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    curl -fsSL -o "$tmp/sockseek.tar.gz" \
      "https://github.com/fiso64/slsk-batchdl/releases/download/v$SOCKSEEK_VERSION/sockseek_${SOCKSEEK_VERSION}_$plat.tar.gz"
    tar -xzf "$tmp/sockseek.tar.gz" -C "$tmp"
    mkdir -p "$HOME/.local/bin"
    install -m755 "$tmp/sockseek" "$HOME/.local/bin/sockseek"
    ok "sockseek installed to ~/.local/bin/sockseek"
    command -v sockseek >/dev/null || warn "~/.local/bin isn't on your PATH; add it"
  fi
fi

if [[ -n ${SLSK_USERNAME:-} && -n ${SLSK_PASSWORD:-} ]]; then
  ok "Soulseek login from SLSK_USERNAME/SLSK_PASSWORD"
elif grep -q '^passw = .' "$HOME/.config/nicotine/config" 2>/dev/null; then
  ok "Soulseek login from the Nicotine+ config"
else
  warn "no Soulseek login yet: set SLSK_USERNAME/SLSK_PASSWORD, or log in once with Nicotine+"
fi

[[ $missing == no ]] || { echo "fix the FAILs above, then re-run"; exit 1; }

echo "installing skill"
mkdir -p "$skills"
if [[ -L $dest && $(readlink "$dest") == "$here" ]]; then
  [[ $link == yes ]] && { ok "already linked: $dest -> $here"; exit 0; }
  rm "$dest"  # just our own symlink
elif [[ -e $dest || -L $dest ]]; then
  bak=$dest.bak-$(date +%Y%m%d-%H%M%S)
  mv "$dest" "$bak"
  warn "moved the existing install aside to $bak"
fi
if [[ $link == yes ]]; then
  ln -s "$here" "$dest"
  ok "linked $dest -> $here"
else
  mkdir -p "$dest"
  cp -r "$here/SKILL.md" "$here/bin" "$dest/"
  chmod +x "$dest"/bin/*
  ok "copied to $dest"
fi
echo "done. In Claude Code, ask it to download an album, or run the scripts in $dest/bin by hand."
