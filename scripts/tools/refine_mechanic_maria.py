#!/usr/bin/env python3
"""Refine the mechanic sprite toward Maria Custard (Rance), round 2.

Input must be the pristine derived sheets (original stable glasses, wizard
wand+orb still in hand). Per frame:
- hair family shifted from deep navy toward Maria's brighter blue
- wizard wand/orb erased via flood fill from amber seeds, then replaced by
  a wrench (left hand) and an electric drill (right hand)
- red necktie painted at the collar, anchored to the cyan glasses lenses
  (stable per-frame anchors painted by the earlier pipeline)
Glasses are intentionally NOT touched: the original iris-anchored rings are
stable; redrawing them from face bbox detection caused jitter.
"""
import os
from collections import deque
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

HAIR_DELTA = (14, 48, 58)
OUTLINE = (9, 4, 17, 255)
TIE = (196, 52, 56, 255)
TIE_DARK = (120, 24, 30, 255)
STEEL_DARK = (58, 66, 84, 255)
STEEL_MID = (110, 124, 148, 255)
STEEL_LIGHT = (168, 182, 204, 255)
STEEL_HI = (226, 234, 244, 255)
AMBER = (242, 169, 59, 255)
AMBER_LIGHT = (255, 210, 122, 255)
AMBER_DARK = (176, 106, 26, 255)


def is_hair(p):
    r, g, b, a = p
    if a < 200 or min(r, g, b) > 175:
        return False
    return b > 100 and b > r + 18 and g >= r - 6


def recolor_hair(img):
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            if is_hair(p):
                px[x, y] = (min(255, p[0] + HAIR_DELTA[0]),
                            min(255, p[1] + HAIR_DELTA[1]),
                            min(255, p[2] + HAIR_DELTA[2]), p[3])


def is_lens(p):
    r, g, b, a = p
    return a > 200 and r < 228 and g > 212 and b > 228


def lens_anchor(img):
    """Center of the cyan glasses lenses; None if not found."""
    px = img.load()
    w, h = img.size
    pts = [(x, y) for y in range(h) for x in range(w) if is_lens(px[x, y])]
    if len(pts) < 4:
        return None
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    return cx, cy, max(p[1] for p in pts)


def is_weapon_family(p):
    r, g, b, a = p
    if a < 120:
        return False
    if r > 210 and (r - g) >= 40 and b < 150:      # amber / glow
        return True
    if r < 70 and g < 70 and b < 80:               # dark outline
        return True
    if 130 <= r <= 200 and 90 <= g <= 165 and 70 <= b <= 145 and 15 <= (r - g) <= 65:
        return True                                 # wooden rod
    return False


def is_seed(p):
    r, g, b, a = p
    return a > 200 and r > 215 and (r - g) >= 42 and 60 <= b < 150


def erase_weapons(img):
    """Flood fill from amber seeds through the weapon color family.
    Returns (left_bbox, right_bbox) of the erased clusters."""
    w, h = img.size
    px = img.load()
    seeds = [(x, y) for y in range(h) for x in range(w) if is_seed(px[x, y])]
    visited = set()
    clusters = []
    for seed in seeds:
        if seed in visited:
            continue
        q = deque([seed])
        visited.add(seed)
        pts = []
        while q and len(pts) < 900:
            x, y = q.popleft()
            pts.append((x, y))
            for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
                if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in visited and is_weapon_family(px[nx, ny]):
                    visited.add((nx, ny))
                    q.append((nx, ny))
        if len(pts) >= 12:
            clusters.append(pts)
    if len(clusters) < 2:
        return None
    # keep the two largest clusters, sort left/right by mean x
    clusters.sort(key=len, reverse=True)
    items = clusters[:2]
    bboxes = []
    for pts in items:
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        bboxes.append((min(xs), min(ys), max(xs), max(ys), sum(xs)/len(xs), sum(ys)/len(ys)))
        for x, y in pts:
            px[x, y] = (0, 0, 0, 0)
    # dilate the erase by 1px to catch anti-aliased fringes
    fringe = set()
    for pts in items:
        for x, y in pts:
            for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
                if 0 <= nx < w and 0 <= ny < h:
                    fringe.add((nx, ny))
    for x, y in fringe:
        r, g, b, a = px[x, y]
        if a > 0 and is_weapon_family(px[x, y]):
            px[x, y] = (0, 0, 0, 0)
    bboxes.sort(key=lambda b: b[4])
    return bboxes[0], bboxes[1]


def erase_weapons_at(img, cx, cy):
    """Fallback for frames where the flood fill failed: erase weapon-family
    pixels inside a window around the predicted position."""
    px = img.load()
    w, h = img.size
    x0 = max(0, int(cx) - 16)
    x1 = min(w - 1, int(cx) + 16)
    y0 = max(0, int(cy) - 16)
    y1 = min(h - 1, int(cy) + 16)
    erased = 0
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if is_weapon_family(px[x, y]):
                px[x, y] = (0, 0, 0, 0)
                erased += 1
    return erased


def purge_seed_specks(img):
    """Erase leftover detached amber sparkles (orb particles) that the flood
    fill could not reach. Must run before drawing the new tools, since the
    drill uses amber too."""
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if is_seed(px[x, y]):
                px[x, y] = (0, 0, 0, 0)


def draw_wrench(d, cx, cy):
    """Open-end wrench, vertical, ~9x22px centered on (cx, cy)."""
    x = int(cx) - 2
    y = int(cy) - 10
    # handle
    d.rectangle([x, y + 7, x + 4, y + 21], fill=STEEL_MID, outline=OUTLINE)
    d.line([x + 1, y + 8, x + 1, y + 19], fill=STEEL_HI)
    # open jaw at top (C shape opening right)
    d.rectangle([x - 2, y, x + 6, y + 7], fill=STEEL_LIGHT, outline=OUTLINE)
    d.rectangle([x + 2, y + 2, x + 7, y + 5], fill=(0, 0, 0, 0))
    # grip hole at bottom
    d.rectangle([x + 1, y + 17, x + 3, y + 19], fill=STEEL_DARK)


def draw_drill(d, cx, cy):
    """Pistol-grip electric drill pointing right, ~16x13px at (cx, cy)."""
    x = int(cx) - 7
    y = int(cy) - 5
    # body
    d.rectangle([x, y, x + 10, y + 6], fill=STEEL_MID, outline=OUTLINE)
    d.rectangle([x + 1, y + 1, x + 9, y + 2], fill=STEEL_LIGHT)
    d.rectangle([x + 2, y + 4, x + 6, y + 5], fill=AMBER)          # amber band
    # handle + trigger
    d.rectangle([x + 1, y + 7, x + 4, y + 12], fill=STEEL_DARK, outline=OUTLINE)
    d.point((x + 5, y + 8), fill=AMBER_DARK)
    # chuck + bit pointing right
    d.rectangle([x + 11, y + 1, x + 12, y + 5], fill=STEEL_DARK, outline=OUTLINE)
    d.rectangle([x + 13, y + 2, x + 16, y + 4], fill=STEEL_HI, outline=OUTLINE)
    d.point((x + 17, y + 3), fill=OUTLINE)


def draw_tie(d, cx, top):
    d.polygon([(cx - 2, top), (cx + 2, top), (cx + 1, top + 3), (cx - 1, top + 3)],
              fill=TIE, outline=TIE_DARK)
    d.polygon([(cx - 1, top + 3), (cx + 1, top + 3), (cx + 2, top + 8), (cx, top + 10), (cx - 2, top + 8)],
              fill=TIE, outline=TIE_DARK)


def process_sheet(path, frame_w, frame_h, cols, rows):
    img = Image.open(path).convert("RGBA")
    frames = {}
    left_offsets = []
    right_offsets = []
    anchors = {}
        # pass 1: recolor + detect weapons; remember positions relative to lenses
    for row in range(rows):
        for col in range(cols):
            box = (col * frame_w, row * frame_h, (col + 1) * frame_w, (row + 1) * frame_h)
            frame = img.crop(box)
            recolor_hair(frame)
            anchor = lens_anchor(frame)
            erased = erase_weapons(frame)
            if erased is not None:
                purge_seed_specks(frame)
            frames[(row, col)] = (frame, erased)
            if anchor is not None:
                anchors[(row, col)] = anchor
            if erased is not None and anchor is not None:
                left, right = erased
                left_offsets.append((left[4] - anchor[0], (left[1] + left[3]) / 2 - anchor[1]))
                right_offsets.append((right[4] - anchor[0], (right[1] + right[3]) / 2 - anchor[1]))
            img.paste(frame, box)
    # median weapon offsets from successful frames
    def median_offset(offsets):
        if not offsets:
            return None
        xs = sorted(o[0] for o in offsets)
        ys = sorted(o[1] for o in offsets)
        return xs[len(xs) // 2], ys[len(ys) // 2]
    left_med = median_offset(left_offsets)
    right_med = median_offset(right_offsets)
    # pass 2: draw tools; frames that failed detection use the median offset
    for (row, col), (frame, erased) in frames.items():
        d = ImageDraw.Draw(frame)
        anchor = anchors.get((row, col))
        if erased is not None:
            left, right = erased
            draw_wrench(d, left[4], (left[1] + left[3]) / 2)
            draw_drill(d, right[4], (right[1] + right[3]) / 2)
        elif anchor is not None and left_med is not None and right_med is not None:
            lx, ly = anchor[0] + left_med[0], anchor[1] + left_med[1]
            rx, ry = anchor[0] + right_med[0], anchor[1] + right_med[1]
            erase_weapons_at(frame, lx, ly)
            erase_weapons_at(frame, rx, ry)
            purge_seed_specks(frame)
            d = ImageDraw.Draw(frame)
            draw_wrench(d, lx, ly)
            draw_drill(d, rx, ry)
            print("  fallback tools on %s r%dc%d" % (os.path.basename(path), row, col))
        else:
            print("  warn: no anchor for tools on %s r%dc%d" % (os.path.basename(path), row, col))
        if anchor is not None:
            draw_tie(d, int(round(anchor[0])), int(round(anchor[2])) + 7)
        else:
            print("  warn: lenses not found on %s r%dc%d" % (os.path.basename(path), row, col))
        box = (col * frame_w, row * frame_h, (col + 1) * frame_w, (row + 1) * frame_h)
        img.paste(frame, box)
    img.save(path)
    print("refined", path)


def process_portrait(path):
    img = Image.open(path).convert("RGBA")
    recolor_hair(img)
    img.save(path)
    print("refined", path)


def main():
    process_sheet(os.path.join(ROOT, "assets/players/mechanic/mechanic-idle.png"), 245, 138, 12, 1)
    process_sheet(os.path.join(ROOT, "assets/players/mechanic/mechanic-run.png"), 256, 256, 4, 3)
    process_portrait(os.path.join(ROOT, "assets/UI/facility/机械师.png"))
    process_portrait(os.path.join(ROOT, "assets/UI/facility/机械师head.png"))


if __name__ == "__main__":
    main()
