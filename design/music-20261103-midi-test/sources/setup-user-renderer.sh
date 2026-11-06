#!/usr/bin/env bash
set -euo pipefail
dest="${1:-$HOME/.local/share/my-game/music-transcription/midi-render}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fetch_extract() {
  name="$1"; path="$2"; expected="$3"
  file="$work/$name.deb"
  curl -fL "https://archive.ubuntu.com/ubuntu/$path" -o "$file"
  printf '%s  %s\n' "$expected" "$file" | sha256sum -c -
  dpkg-deb -x "$file" "$dest"
}
mkdir -p "$dest"
fetch_extract fluidsynth pool/universe/f/fluidsynth/fluidsynth_2.3.4-1build3_amd64.deb c91c2528fed6d2ec97ba65dc6cba93c6a2096ea3147e47889a420bb9df8f36b0
fetch_extract libfluidsynth3 pool/universe/f/fluidsynth/libfluidsynth3_2.3.4-1build3_amd64.deb 645b2c03798b6e02d289cc27f4b2b25a040db705cf527017e3a6cdbe568b3438
fetch_extract libinstpatch pool/universe/libi/libinstpatch/libinstpatch-1.0-2_1.1.6-1build2_amd64.deb d48c40a9c428e40d5bbe8762802390322b06a062c735292767e73d1c6ea9007e
printf 'FluidSynth extracted to %s\n' "$dest"
