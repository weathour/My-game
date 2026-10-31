"""Read-only checks for boss human-form exports; writes only local audit JSON/status."""
from __future__ import annotations

import argparse
from hashlib import sha256
import json
from pathlib import Path
import struct
import sys

from PIL import Image

ROOT = Path('design/boss-forms-20261029')
RUNTIME = Path('assets/enemies/baimen')
REQUIRED_DISTINCT = {'idle', 'move', 'attack', 'death'}


def digest(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def resolve(path: str, base: Path) -> Path:
    raw = path.removeprefix('res://')
    candidate = Path(raw)
    if candidate.is_absolute():
        return candidate
    if candidate.exists():
        return candidate
    return base / candidate


def source_records(metadata: dict, manifest_path: Path) -> list[dict]:
    provenance = metadata.get('provenance')
    provenance_sources = provenance.get('sources') if isinstance(provenance, dict) else None
    raw = metadata.get('sources') or metadata.get('source_files') or provenance_sources
    if isinstance(raw, dict):
        items = [{'kind': key, **value} for key, value in raw.items() if isinstance(value, dict)]
    elif isinstance(raw, list):
        items = raw
    else:
        raise AssertionError('manifest must list provenance sources with path and sha256')
    if not items:
        raise AssertionError('manifest provenance source list is empty')
    records = []
    for item in items:
        source_path = resolve(item['path'], manifest_path.parent)
        actual = digest(source_path)
        assert item['sha256'] == actual, (source_path, 'source hash mismatch')
        records.append({'kind': item.get('kind', ''), 'path': str(source_path), 'sha256': actual,
                        'size': list(item.get('size', [])) if item.get('size') else None})
    return records


def aseprite_info(path: Path) -> dict:
    data = path.read_bytes()
    assert len(data) >= 16, (path, 'truncated Aseprite file')
    magic, frames, width, height = struct.unpack_from('<4H', data, 4)
    assert magic == 0xA5E0, (path, 'invalid Aseprite magic')
    assert frames > 0 and width > 0 and height > 0, (path, 'invalid Aseprite header')
    return {'path': str(path), 'sha256': digest(path), 'size': [width, height], 'frames': frames}


def audit(identity: str) -> None:
    folder = RUNTIME / identity
    manifest_path = folder / 'manifest.json'
    metadata = json.loads(manifest_path.read_text())
    assert metadata.get('visual_id', metadata.get('id')) == identity, 'runtime manifest identity mismatch'
    sources = source_records(metadata, manifest_path)
    clips = metadata.get('clips')
    assert isinstance(clips, dict) and clips, 'manifest clips missing'
    png_files = sorted(folder.glob('*.png'))
    ase_files = sorted(folder.glob('*.aseprite'))
    assert png_files and ase_files, 'runtime PNG and editable Aseprite outputs are required'
    clip_files: dict[Path, tuple[str, dict]] = {}
    for name, clip in clips.items():
        path = folder / clip.get('file', f'{name}.png')
        assert path.is_file(), ('missing runtime clip', path)
        assert path in png_files, ('clip path must be a PNG in the identity folder', path)
        clip_files[path] = (name, clip)
    portrait_spec = metadata.get('portrait')
    portrait_path = folder / portrait_spec.get('file', 'portrait.png') if isinstance(portrait_spec, dict) else folder / 'portrait.png'
    assert portrait_path in png_files, 'portrait PNG required'
    if isinstance(portrait_spec, dict):
        if portrait_spec.get('sha256'):
            assert digest(portrait_path) == portrait_spec['sha256'], 'portrait must preserve the manifest source hash'
        if portrait_spec.get('size'):
            with Image.open(portrait_path) as portrait:
                assert list(portrait.size) == portrait_spec['size'], 'portrait dimensions mismatch'

    palette: set[tuple[int, int, int]] = set()
    outputs = []
    portrait_report = None
    for path in png_files:
        with Image.open(path) as image:
            assert image.mode == 'RGBA', (path, image.mode, 'RGBA required')
            alpha = image.getchannel('A')
            alpha_values = set(alpha.getdata())
            if path == portrait_path:
                assert 0 in alpha_values, (path, 'portrait needs genuine transparency')
                pixels = image.width * image.height
                opaque_count = sum(1 for a in alpha.getdata() if a >= 250)
                assert opaque_count < pixels * 0.95, (path, 'portrait appears to contain a mostly opaque background')
                portrait_report = {'path': str(path), 'size': list(image.size),
                                   'alpha_values': len(alpha_values), 'transparent_pixels': sum(1 for a in alpha.getdata() if a == 0),
                                   'semi_transparent_pixels': sum(1 for a in alpha.getdata() if 0 < a < 255),
                                   'opaque_pixels': opaque_count}
            else:
                assert alpha_values <= {0, 255}, (path, 'runtime alpha must be binary')
                name, clip = clip_files.get(path, (None, None))
                if name:
                    frame_size = clip.get('frame_size') or [clip.get('width'), clip.get('height')]
                    assert all(isinstance(v, int) and v > 0 for v in frame_size), (name, 'frame_size missing')
                    count = clip.get('frames')
                    assert isinstance(count, int) and count > 0, (name, 'frame count missing')
                    fw, fh = frame_size
                    assert image.size == (fw * count, fh), (path, image.size, 'manifest dimensions mismatch')
                    frame_hashes, bounds = [], []
                    for i in range(count):
                        frame = image.crop((i * fw, 0, (i + 1) * fw, fh))
                        bounds.append(frame.getchannel('A').getbbox())
                        assert bounds[-1], (path, i, 'empty frame')
                        frame_hashes.append(sha256(frame.tobytes()).hexdigest())
                    if name in REQUIRED_DISTINCT:
                        assert len(set(frame_hashes)) >= 2, (path, 'at least two distinct frames required')
                    palette.update(px[:3] for px in image.getdata() if px[3])
                    outputs.append({'path': str(path), 'sha256': digest(path), 'size': list(image.size),
                                    'frames': count, 'opaque_colors': len({px[:3] for px in image.getdata() if px[3]}),
                                    'frame_alpha_bounds': bounds, 'frame_pixel_sha256': frame_hashes})
                else:
                    # Any additional non-portrait PNG remains a runtime-style image.
                    palette.update(px[:3] for px in image.getdata() if px[3])
                    outputs.append({'path': str(path), 'sha256': digest(path), 'size': list(image.size)})
    assert len(palette) <= 64, ('shared opaque actor colors exceed 64', len(palette))
    for path in ase_files:
        info = aseprite_info(path)
        if path.stem in clips:
            clip = clips[path.stem]
            expected_size = clip.get('frame_size') or [clip.get('width'), clip.get('height')]
            assert info['size'] == expected_size and info['frames'] == clip['frames'], (path, info, 'clip editable mismatch')
        outputs.append(info)
    assert portrait_report is not None
    outputs.append({'path': str(portrait_path), 'sha256': digest(portrait_path), 'size': portrait_report['size'], 'portrait_alpha': portrait_report})
    metadata['status'] = 'final'
    final_manifest = json.dumps(metadata, ensure_ascii=False, indent=2) + '\n'
    report = {'schema': 1, 'id': identity, 'runtime_manifest': str(manifest_path),
              'runtime_manifest_sha256': sha256(final_manifest.encode()).hexdigest(), 'sources': sources,
              'shared_opaque_actor_colors': len(palette), 'clips': list(clips), 'outputs': outputs}
    report_path = ROOT / 'characters' / identity / 'export-manifest.json'
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    manifest_path.write_text(final_manifest)
    print(f'BOSS_FORM_EXPORT_AUDIT_OK {identity} clips={len(clips)} colors={len(palette)}')


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--id', action='append', default=[])
    p.add_argument('--all', action='store_true')
    args = p.parse_args()
    ids = list(args.id)
    if args.all:
        ids += ['B15_human', 'B16_human', 'B17_human', 'B18_human', 'M03_human', 'M04_human']
    if not ids:
        p.error('provide --id X or --all')
    for identity in dict.fromkeys(ids):
        if not identity or any(not (c.isalnum() or c == '_') for c in identity):
            p.error(f'invalid identity: {identity!r}')
        audit(identity)


if __name__ == '__main__':
    try:
        main()
    except (AssertionError, KeyError, OSError, ValueError, TypeError) as error:
        print(f'BOSS_FORM_EXPORT_AUDIT_FAIL {error}', file=sys.stderr)
        raise SystemExit(1)
