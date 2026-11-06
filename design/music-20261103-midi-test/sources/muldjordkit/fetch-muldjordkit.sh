#!/usr/bin/env bash
set -euo pipefail
dest="${1:-$HOME/.cache/my-game/music-instruments/muldjordkit}"
archive="$dest/MuldjordKit-SF2-20201018.7z"
mkdir -p "$dest"
curl -fL 'https://github.com/freepats/muldjordkit/releases/download/2020-10-18/MuldjordKit-SF2-20201018.7z' -o "$archive"
printf '%s  %s\n' 'aef4c9e0a96f9a899a7838f65ff07565f6af247bbb4ff31e24dba3331a671a96' "$archive" | sha256sum -c -
7z x -y "$archive" -o"$dest"
printf '%s  %s\n' 'fec611c55b5e1c53ea3e6df1e6779c9f18502fc6455ee45edc51d5a2b4881055' "$dest/MuldjordKit-SF2-20201018/MuldjordKit 20201018.sf2" | sha256sum -c -
