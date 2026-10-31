"""Read-only 4-connected source component inventory for human-form artwork."""
from __future__ import annotations

import argparse
from hashlib import sha256
import json
from pathlib import Path
import sys

from PIL import Image

ROOT = Path('design/boss-forms-20261029')


def inventory(path: Path) -> dict:
    with Image.open(path) as im:
        if im.mode != 'RGBA':
            raise ValueError(f'{path}: expected actual RGBA image, got {im.mode}')
        width, height = im.size
        alpha = im.getchannel('A').tobytes()
    seen = bytearray(width * height)
    found = []
    for start, value in enumerate(alpha):
        if value < 128 or seen[start]:
            continue
        seen[start] = 1
        stack = [start]
        area = 0
        x0 = x1 = start % width
        y0 = y1 = start // width
        while stack:
            pos = stack.pop()
            x, y = pos % width, pos // width
            area += 1
            x0, x1 = min(x0, x), max(x1, x)
            y0, y1 = min(y0, y), max(y1, y)
            for nxt in (pos - 1 if x else -1, pos + 1 if x + 1 < width else -1,
                        pos - width if y else -1, pos + width if y + 1 < height else -1):
                if nxt >= 0 and not seen[nxt] and alpha[nxt] >= 128:
                    seen[nxt] = 1
                    stack.append(nxt)
        found.append({'bbox': [x0, y0, x1 + 1, y1 + 1], 'area': area})
    found.sort(key=lambda c: (c['bbox'][1], c['bbox'][0], -c['area']))
    bodies = [c for c in found if c['area'] >= 2000]
    groups = [{'body': body, 'components': []} for body in bodies]
    # Associate each non-body component with its nearest large component bbox.
    # Distances are geometric only; this report does not select poses or anchors.
    def bbox_distance(a: list[int], b: list[int]) -> int:
        dx = max(a[0] - b[2], b[0] - a[2], 0)
        dy = max(a[1] - b[3], b[1] - a[3], 0)
        return dx * dx + dy * dy
    for component in found:
        if component['area'] >= 2000 or not groups:
            continue
        target = min(range(len(groups)), key=lambda i: (bbox_distance(component['bbox'], groups[i]['body']['bbox']), i))
        groups[target]['components'].append(component)
    return {'path': str(path), 'sha256': sha256(path.read_bytes()).hexdigest(),
            'size': [width, height], 'alpha_threshold': 128, 'connectivity': 4,
            'large_body_area_threshold': 2000, 'component_count': len(found),
            'components': found, 'large_bodies_with_nearest_components': groups}


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--id', required=True)
    p.add_argument('--source', type=Path)
    p.add_argument('--output', type=Path)
    args = p.parse_args()
    if not args.id or any(not (c.isalnum() or c == '_') for c in args.id):
        p.error('invalid identity')
    source = args.source or ROOT / 'characters' / args.id / 'source' / 'actions-v1.png'
    result = inventory(source)
    output = args.output or ROOT / 'characters' / args.id / 'source-components.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(f'SOURCE_COMPONENTS_OK {args.id} components={result["component_count"]} bodies={len(result["large_bodies_with_nearest_components"])} report={output}')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as error:
        print(f'SOURCE_COMPONENTS_FAIL {error}', file=sys.stderr)
        raise SystemExit(1)
