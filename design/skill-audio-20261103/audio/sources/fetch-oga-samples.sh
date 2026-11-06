#!/usr/bin/env bash
set -euo pipefail
out="$(cd "$(dirname "$0")" && pwd)/oga-80-cc0-rpg-sfx"
wet_out="$(cd "$(dirname "$0")" && pwd)/oga-40-water-splash-slime"
recorded_out="$(cd "$(dirname "$0")" && pwd)/oga-100-cc0-sfx"
repo='https://github.com/Silentnoob21/cc0-public-domain-sounds.git'
commit='f2b6264f9ab89fabc266914c3654685d68c5a39b'
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$out" "$wet_out" "$recorded_out"
git -C "$work" init -q
git -C "$work" remote add origin "$repo"
git -C "$work" fetch -q --depth=1 --filter=blob:none origin "$commit"
files=(blade_01 blade_02 blade_03 chain_01 chain_02 metal_01 metal_02 stones_01 stones_02 wood_01 wood_02 creature_hurt_01 creature_hurt_02 creature_misc_03 creature_monster_02 creature_roar_01 creature_die_01 item_gem_01 item_gem_02 item_gem_03 spell_01 spell_02 spell_fire_02 spell_fire_05)
for name in "${files[@]}"; do
  git -C "$work" show "FETCH_HEAD:80-CC0-RPG-SFX/${name}.ogg" > "$out/${name}.ogg"
done
wet_files=(splash_03 splash_05 splash_13 bubble_03 slime_01 slime_06)
for name in "${wet_files[@]}"; do
  git -C "$work" show "FETCH_HEAD:40-cc0-water-splash-slime-sfx/${name}.ogg" > "$wet_out/${name}.ogg"
done
recorded_files=(explosion hit_01 hit_02 glass_02 metal_03 metal_05 slam_04 wooden_01)
for name in "${recorded_files[@]}"; do
  git -C "$work" show "FETCH_HEAD:100-CC0-SFX/${name}.ogg" > "$recorded_out/${name}.ogg"
done
git -C "$work" show 'FETCH_HEAD:LICENSE' > "$out/CC0-1.0.txt"
cp "$out/CC0-1.0.txt" "$wet_out/CC0-1.0.txt"
cp "$out/CC0-1.0.txt" "$recorded_out/CC0-1.0.txt"
