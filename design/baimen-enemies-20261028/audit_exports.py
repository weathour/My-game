"""Read-only raster/source QA. Writes only per-identity provenance and status JSON.

--source IMAGE lists true 4-connected alpha>=128 regions; no image transformations.
--id E01 --preflight verifies the reviewed measurements BEFORE Aseprite export.
--id E01 audits exported images/editable files and marks the runtime manifest final.
Multiple --id options or --all support independent workers without a global write.
"""
from __future__ import annotations

import argparse
from hashlib import sha256
import json
from math import floor
from pathlib import Path
import struct
import sys

from PIL import Image

ROOT = Path('design/baimen-enemies-20261028')
CLIPS = ('idle', 'move', 'attack', 'special', 'hit')


def digest(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def components(path: Path, minimum: int = 1) -> dict:
    import numpy as np
    from scipy.ndimage import label, find_objects
    with Image.open(path) as image:
        assert image.mode == 'RGBA', (path, 'source must be actual RGBA')
        labels, _ = label(np.asarray(image.getchannel('A')) >= 128)
        sizes = np.bincount(labels.ravel())
        found = []
        for i, region in enumerate(find_objects(labels), 1):
            if region is not None and sizes[i] >= minimum:
                y, x = region
                found.append({'bbox': [x.start, y.start, x.stop, y.stop], 'area': int(sizes[i])})
        return {'path': str(path), 'sha256': digest(path), 'size': list(image.size),
                'alpha_threshold': 128, 'connectivity': 4,
                'components': sorted(found, key=lambda item: (item['bbox'][1], item['bbox'][0]))}


def resolve(folder: Path, value: str) -> Path:
    path = Path(value)
    return path if path.is_absolute() else folder / path


def preflight(path: Path) -> tuple[dict, list]:
    m = json.loads(path.read_text())
    assert m['version'] == 1 and m['review_status'] == 'accepted_for_export', 'reviewed version1 measurements required'
    assert m['id'] and all(c.isupper() or c.isdigit() or c == '_' for c in m['id']), 'invalid identity'
    canvas = m['canvas']
    width, height = canvas['size']
    ax, ay = canvas['anchor']
    assert width > 0 and height > 0 and 0 <= ax <= width and 0 <= ay <= height
    assert canvas['body_height_px'] > 0
    assert m.get('review_notes', '').strip(), 'record visual review and weapon/component decisions'
    assert m.get('prompts'), 'ImageGen prompts must be preserved'
    for prompt in m['prompts']:
        assert resolve(path.parent, prompt).is_file(), ('missing prompt', prompt)
    sources, inspected = [], {}
    for key, source in m['sources'].items():
        source_path = resolve(path.parent, source['path'])
        assert digest(source_path) == source['sha256'], (source_path, 'source changed after measurement')
        record = components(source_path)
        assert record['size'] == source['size'], (source_path, 'dimensions changed')
        assert source['standing_body_height'] > 0
        inspected[key] = {tuple(part['bbox']): part['area'] for part in record['components']}
        sources.append({'kind': key, 'path': str(source_path), 'sha256': record['sha256'],
                        'size': record['size'], 'standing_body_height': source['standing_body_height'],
                        'scale': canvas['body_height_px'] / source['standing_body_height']})
    pose_ids = set()
    for pose in m['poses']:
        assert pose['id'] not in pose_ids, ('duplicate pose id', pose['id'])
        pose_ids.add(pose['id'])
        source = m['sources'][pose['source']]
        assert pose['components'], ('empty pose', pose['id'])
        selected = set()
        for part in pose['components']:
            bounds = tuple(part['bbox'])
            assert bounds not in selected, ('duplicate component', pose['id'])
            selected.add(bounds)
            assert inspected[pose['source']].get(bounds) == part['area'], ('component changed', pose['id'], part)
        x0 = min(b[0] for b in selected); y0 = min(b[1] for b in selected)
        x1 = max(b[2] for b in selected); y1 = max(b[3] for b in selected)
        scale = canvas['body_height_px'] / source['standing_body_height']
        rnd = lambda n: floor(n + .5)
        x = ax - rnd((pose['anchor_source'][0] - x0) * scale)
        y = ay - rnd((pose['anchor_source'][1] - y0) * scale)
        assert x >= 0 and y >= 0 and x + rnd((x1-x0)*scale) <= width and y + rnd((y1-y0)*scale) <= height, ('output would clip', pose['id'])
    assert pose_ids
    assert set(CLIPS) <= set(m['clips']), 'five baseline clips required'
    for name in m['clips']:
        assert name and all(c.islower() or c.isdigit() or c == '_' for c in name), ('invalid clip filename', name)
        clip = m['clips'][name]
        assert clip['poses'] and clip['fps'] > 0
        assert all(p in pose_ids for p in clip['poses']), ('unknown clip pose', name)
        for frame in ('contact_frame', 'windup_frame'):
            if frame in clip: assert 0 <= clip[frame] < len(clip['poses']), (name, frame)
    for action, clip in m.get('action_clips', {}).items():
        assert clip in m['clips'], ('unknown action clip', action, clip)
    portrait_path = resolve(path.parent, m['portrait']['path'])
    assert digest(portrait_path) == m['portrait']['sha256'], 'standing portrait changed'
    with Image.open(portrait_path) as portrait:
        assert portrait.mode == 'RGBA' and list(portrait.size) == m['portrait']['size']
        assert portrait.getchannel('A').getextrema()[0] == 0, 'standing portrait needs genuine transparency'
    sources.append({'kind':'portrait', 'path':str(portrait_path), 'sha256':digest(portrait_path), 'size':m['portrait']['size']})
    return m, sources


def editable(path: Path, count: int, size: tuple[int, int]) -> dict:
    data = path.read_bytes()
    magic, frames, width, height = struct.unpack_from('<4H', data, 4)
    assert magic == 0xA5E0 and frames == count and (width, height) == size, (path, frames, width, height)
    return {'path':str(path), 'sha256':digest(path), 'size':[width,height], 'frames':frames}


def audit(path: Path, folder: Path, report_path: Path) -> None:
    m, sources = preflight(path)
    metadata_path = folder / 'manifest.json'
    metadata = json.loads(metadata_path.read_text())
    assert metadata['visual_id'] == m['id'] and metadata['version'] == 1
    assert metadata['body_height_px'] == m['canvas']['body_height_px'] and metadata['anchor_px'] == m['canvas']['anchor']
    width, height = m['canvas']['size']
    colors, outputs = set(), []
    assert metadata.get('action_clips', {}) == m.get('action_clips', {}), 'action clip mapping mismatch'
    for name in m['clips']:
        clip = m['clips'][name]
        count = len(clip['poses'])
        assert metadata['clips'][name]['frames'] == count and metadata['clips'][name]['fps'] == clip['fps']
        image_path = folder / f'{name}.png'
        with Image.open(image_path) as image:
            assert image.mode == 'RGBA' and image.size == (width*count, height), (image_path, image.mode, image.size)
            assert set(image.getchannel('A').getdata()) == {0,255}, (image_path, 'binary alpha required')
            palette = {px[:3] for px in image.getdata() if px[3]}
            colors.update(palette)
            bounds, frame_hashes = [], []
            for frame in range(count):
                region = image.crop((frame*width, 0, (frame+1)*width, height))
                bounds.append(region.getchannel('A').getbbox())
                assert bounds[-1], (image_path, frame, 'empty frame')
                frame_hashes.append(sha256(region.tobytes()).hexdigest())
            if not clip.get('allow_repeated_frames', False):
                assert len(set(frame_hashes)) == count, (image_path, 'duplicate frames; review or explicitly approve repeats')
            outputs.append({'path':str(image_path), 'sha256':digest(image_path), 'size':list(image.size),
                            'frames':count, 'opaque_colors':len(palette), 'frame_alpha_bounds':bounds,
                            'frame_pixel_sha256':frame_hashes})
        outputs.append(editable(folder/f'{name}.aseprite', count, (width,height)))
    assert len(colors) <= 64, ('shared actor palette exceeds64', len(colors))
    outputs.append(editable(folder/'actor.aseprite', len(m['poses']), (width,height)))
    portrait_path = folder/'portrait.png'
    assert digest(portrait_path) == m['portrait']['sha256'], 'portrait must remain full source, no crop or regeneration'
    outputs.append({'path':str(portrait_path), 'sha256':digest(portrait_path), 'size':m['portrait']['size']})
    outputs.append(editable(folder/'portrait.aseprite', 1, tuple(m['portrait']['size'])))
    report = {'schema':1, 'id':m['id'], 'generator':'ImageGen pixels / Aseprite reviewed-part extraction and registration',
              'measurements':str(path), 'measurements_sha256':digest(path),
              'export_script':'scripts/tools/import_baimen_enemy_art.lua',
              'export_script_sha256':digest(Path('scripts/tools/import_baimen_enemy_art.lua')),
              'audit_script_sha256':digest(Path(__file__)), 'sources':sources,
              'actor_shared_opaque_colors':len(colors), 'actor_frames':sum(len(clip['poses']) for clip in m['clips'].values()),
              'frame_size':[width,height], 'anchor':m['canvas']['anchor'], 'outputs':outputs}
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
    metadata['status'] = 'final'
    metadata_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2)+'\n')
    print(f"BAIMEN_ENEMY_AUDIT_OK {m['id']} frames={report['actor_frames']} colors={len(colors)}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path)
    parser.add_argument('--min-area', type=int, default=1)
    parser.add_argument('--id', action='append', default=[])
    parser.add_argument('--all', action='store_true')
    parser.add_argument('--measurements', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--report', type=Path)
    parser.add_argument('--preflight', action='store_true')
    args = parser.parse_args()
    if args.source:
        print(json.dumps(components(args.source, args.min_area), ensure_ascii=False, indent=2)); return
    ids = args.id
    if args.all: ids += [p.parent.name for p in sorted((ROOT/'characters').glob('*/measurements.json'))]
    if args.measurements and not ids: ids = [json.loads(args.measurements.read_text())['id']]
    if not ids: parser.error('provide --id, --all, --measurements or --source')
    if len(ids) > 1 and any((args.measurements, args.output, args.report)): parser.error('overrides require a single identity')
    for id in dict.fromkeys(ids):
        path = args.measurements or ROOT/'characters'/id/'measurements.json'
        if args.preflight:
            m, _ = preflight(path)
            assert m['id'] == id
            print(f"BAIMEN_ENEMY_PREFLIGHT_OK {id} reviewed_poses={len(m['poses'])}")
        else:
            audit(path, args.output or Path('assets/enemies/baimen')/id,
                  args.report or ROOT/'characters'/id/'export-manifest.json')


if __name__ == '__main__':
    try:
        main()
    except (AssertionError, KeyError, OSError, ValueError) as error:
        print(f'BAIMEN_ENEMY_ART_AUDIT_FAIL {error}', file=sys.stderr)
        raise SystemExit(1)
