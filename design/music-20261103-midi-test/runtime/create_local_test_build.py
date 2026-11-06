#!/usr/bin/env python3
"""Package a verified development PCK with the installed 4.6.2 runtime."""
import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--pck', type=Path, required=True)
    parser.add_argument('--godot', type=Path, default=Path('/home/weathour/.local/bin/godot-4.6.2'))
    parser.add_argument('--output', type=Path, default=ROOT / 'builds/linux-midi-test-20261103')
    args = parser.parse_args()
    version = subprocess.check_output([str(args.godot), '--version'], text=True).strip()
    assert version.startswith('4.6.2.'), version
    assert args.pck.is_file() and args.pck.stat().st_size > 1000
    args.output.mkdir(parents=True, exist_ok=True)
    binary = args.output / 'godot-4.6.2'
    pack = args.output / 'game.pck'
    shutil.copy2(args.godot.resolve(), binary)
    shutil.copy2(args.pck, pack)
    (args.output / 'empty-cwd').mkdir(exist_ok=True)
    launcher = args.output / 'run.sh'
    launcher.write_text('''#!/usr/bin/env bash
set -euo pipefail
PACKAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export XDG_DATA_HOME="$PACKAGE_DIR/test-user-data/data"
export XDG_CONFIG_HOME="$PACKAGE_DIR/test-user-data/config"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$PACKAGE_DIR/empty-cwd"
cd "$PACKAGE_DIR/empty-cwd"
exec "$PACKAGE_DIR/godot-4.6.2" --path "$PACKAGE_DIR/empty-cwd" --main-pack "$PACKAGE_DIR/game.pck" "$@"
''')
    launcher.chmod(0o755)
    license_inputs = [ROOT / 'THIRD_PARTY_NOTICES.md', ROOT / 'design/music-20261103-midi-test/THIRD_PARTY_NOTICES.md']
    license_inputs += [path for path in (ROOT / 'design/music-20261103-midi-test/sources').rglob('*') if path.is_file() and any(token in path.name.lower() for token in ('license', 'copying', 'copyright', 'notice'))]
    license_inputs += [path for path in (ROOT / 'assets').rglob('*') if path.is_file() and not path.name.endswith('.import') and any(token in path.name.lower() for token in ('license', 'copying', 'copyright', 'attribution'))]
    license_inputs += list((Path(__file__).resolve().parent / 'licenses/godot-4.6.2').glob('*'))
    source_materials = [
        'design/music-20261103-midi-test/experiment-manifest.json',
        'design/music-20261103-midi-test/chapter-music-map.json',
        'design/music-20261103-midi-test/instrument-source-lock.json',
        'design/music-20261103-midi-test/audio-production-release-report.json',
        'design/music-20261103-midi-test/README.md',
        'design/music-20261030/THIRD_PARTY_NOTICES.md',
        'design/music-20261030/instrument-manifest.json',
        'design/music-20261030/README.md',
        'design/music-20261030/audio_engine.py',
        'design/music-20261030/engine-evidence/engine-freeze.json',
    ]
    license_inputs += [ROOT / path for path in source_materials]
    for directory in ['design/music-20261103-midi-test/sources', 'design/music-20261103-midi-test/reports']:
        license_inputs += [path for path in (ROOT / directory).rglob('*') if path.is_file() and path.suffix in ['.md', '.txt', '.json', '.sh']]
    assert all(path.is_file() for path in license_inputs)
    license_files = []
    for source in sorted(set(license_inputs)):
        relative = source.relative_to(ROOT)
        destination = args.output / 'notices' / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        license_files.append({'path': str(destination.relative_to(args.output)), 'source': str(relative), 'sha256': sha256(destination)})
    assert len(license_files) >= 9
    manifest = {
        'type': 'local_linux_development_pack_with_godot_runtime',
        'preset': 'Linux development',
        'godot_version': version,
        'runtime_sha256': sha256(binary),
        'pck_sha256': sha256(pack),
        'pck_bytes': pack.stat().st_size,
        'catalog_sha256': sha256(ROOT / 'assets/data/audio/music_catalog.json'),
        'cue_ids': [row['id'] for row in json.loads((ROOT / 'assets/data/audio/music_catalog.json').read_text())['cues']],
        'launcher': str(launcher),
        'notices_and_licenses': license_files,
        'player_data_policy': 'package-local test-user-data via XDG_DATA_HOME/XDG_CONFIG_HOME; no existing player directory',
    }
    (args.output / 'build-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
