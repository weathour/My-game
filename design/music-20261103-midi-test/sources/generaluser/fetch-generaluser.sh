#!/usr/bin/env bash
set -euo pipefail
dest="${1:-$HOME/.local/share/my-game/music-transcription/midi-render/soundfonts}"
repo="$dest/GeneralUser-GS-source"
mkdir -p "$dest"
git clone --filter=blob:none --no-checkout https://github.com/mrbumpy409/GeneralUser-GS.git "$repo"
git -C "$repo" checkout --detach 684543d5e5efaef08d02be50dcda8d552478fa60
sf2="$(find "$repo" -type f -iname '*.sf2' -print -quit)"
test -n "$sf2"
install -m 0644 "$sf2" "$dest/GeneralUser-GS.sf2"
printf '%s  %s\n' '9575028c7a1f589f5770fccc8cff2734566af40cd26ed836944e9a5152688cfe' "$dest/GeneralUser-GS.sf2" | sha256sum -c -
