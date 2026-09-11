#!/usr/bin/env python3
"""Re-derive the mechanic sheets from the wizard sheets WITHOUT the later
add-ons (round glasses, wrench/drill, red necktie).

The original k-means(24) conversion script was never committed, so this
rebuilds the exact wizard->mechanic color mapping as a lookup table recovered
from the current sheets: for every wizard color, the dominant mechanic color
at the same pixel across all frames is the mapping, after discarding pairs
that belong to the added elements (steel tool colors, tie reds, dark ring
pixels painted over bright base colors). Wizard colors that only survive
under the erased wand/orb area fall back to the amber family by luminance.
"""
import os
from collections import Counter, defaultdict
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

OUTLINE = (9, 4, 17)
TOOL_COLORS = {
    (58, 66, 84), (110, 124, 148), (168, 182, 204), (226, 234, 244),
    (242, 169, 59), (176, 106, 26), (255, 210, 122),
}
TIE_COLORS = {(196, 52, 56), (120, 24, 30)}
POLLUTED = TOOL_COLORS | TIE_COLORS

SHEETS = [
    ("assets/players/wizard/wizard-idle.png", "assets/players/mechanic/mechanic-idle.png"),
    ("assets/players/wizard/wizard-run.png", "assets/players/mechanic/mechanic-run.png"),
]

PORTRAITS = [
    ("assets/UI/facility/术师.png", "assets/UI/facility/机械师.png"),
    ("assets/UI/facility/术师head.png", "assets/UI/facility/机械师head.png"),
]


def is_dark(c):
    return max(c) < 80


def build_lut():
    votes = defaultdict(Counter)
    for wiz_path, mec_path in SHEETS:
        wiz = Image.open(os.path.join(ROOT, wiz_path)).convert("RGBA")
        mec = Image.open(os.path.join(ROOT, mec_path)).convert("RGBA")
        assert wiz.size == mec.size, (wiz.size, mec.size)
        wp, mp = wiz.load(), mec.load()
        w, h = wiz.size
        for y in range(h):
            for x in range(w):
                wc, mc = wp[x, y], mp[x, y]
                if wc[3] <= 100 or mc[3] <= 100:
                    continue
                wc3, mc3 = wc[:3], mc[:3]
                if mc3 in POLLUTED:
                    continue
                if mc3 == OUTLINE and not is_dark(wc3):
                    continue  # glasses rings / tool outlines painted over bright pixels
                votes[wc3][mc3] += 1
    lut = {}
    ambiguous = []
    for wc3, counter in votes.items():
        total = sum(counter.values())
        best, best_n = counter.most_common(1)[0]
        lut[wc3] = best
        if best_n / total < 0.6:
            ambiguous.append((wc3, best, best_n / total, counter.most_common(3)))
    return lut, votes, ambiguous


# wizard colors absent from the current sheets (purged sparkles / overwritten
# orb / erased mouth) mapped by hand: mouth stays as-is, orb core and its warm
# glow become the amber family per the original "orb -> amber energy core".
AMBER_DARK = (176, 106, 26)
AMBER = (242, 169, 59)
AMBER_LIGHT = (255, 210, 122)
FALLBACK_MAP = {
    (255, 143, 143): (255, 143, 143),   # mouth, wrongly purged as a sparkle
    (109, 67, 248): AMBER,              # orb core
    (120, 92, 248): AMBER_LIGHT,        # orb core highlight
    (217, 117, 90): AMBER,              # orb glow
    (230, 148, 121): AMBER_LIGHT,
    (238, 173, 146): AMBER_LIGHT,
    (241, 179, 114): AMBER_LIGHT,
}


def nearest_lut(lut, c):
    best, best_d = None, 1 << 62
    for k, v in lut.items():
        d = (k[0] - c[0]) ** 2 + (k[1] - c[1]) ** 2 + (k[2] - c[2]) ** 2
        if d < best_d:
            best, best_d = v, d
    return best


def convert(lut):
    for wiz_path, mec_path in SHEETS:
        wiz = Image.open(os.path.join(ROOT, wiz_path)).convert("RGBA")
        wp = wiz.load()
        w, h = wiz.size
        out = Image.new("RGBA", (w, h))
        op = out.load()
        fallback_count = 0
        for y in range(h):
            for x in range(w):
                wc = wp[x, y]
                if wc[3] == 0:
                    continue
                wc3 = wc[:3]
                if wc3 in lut:
                    mc3 = lut[wc3]
                elif wc3 in FALLBACK_MAP:
                    mc3 = FALLBACK_MAP[wc3]
                else:
                    mc3 = nearest_lut(lut, wc3)
                    fallback_count += 1
                op[x, y] = mc3 + (wc[3],)
        out_path = os.path.join(ROOT, mec_path)
        out.save(out_path)
        print("converted", mec_path, "nearest-fallback px:", fallback_count)


def build_portrait_lut():
    votes = defaultdict(Counter)
    for src_path, dst_path in PORTRAITS:
        src = Image.open(os.path.join(ROOT, src_path)).convert("RGBA")
        dst = Image.open(os.path.join(ROOT, dst_path)).convert("RGBA")
        assert src.size == dst.size, (src.size, dst.size)
        sp, dp = src.load(), dst.load()
        w, h = src.size
        for y in range(h):
            for x in range(w):
                sc, dc = sp[x, y], dp[x, y]
                if sc[3] <= 100 or dc[3] <= 100:
                    continue
                sc3, dc3 = sc[:3], dc[:3]
                if dc3 in POLLUTED:
                    continue
                if is_dark(dc3) and not is_dark(sc3):
                    continue  # glasses rings painted over skin/hair
                votes[sc3][dc3] += 1
    return {sc3: counter.most_common(1)[0][0] for sc3, counter in votes.items()}


def convert_portraits():
    lut = build_portrait_lut()
    print("portrait lut colors:", len(lut))
    for src_path, dst_path in PORTRAITS:
        src = Image.open(os.path.join(ROOT, src_path)).convert("RGBA")
        sp = src.load()
        w, h = src.size
        out = Image.new("RGBA", (w, h))
        op = out.load()
        fallback_count = 0
        for y in range(h):
            for x in range(w):
                sc = sp[x, y]
                if sc[3] == 0:
                    continue
                sc3 = sc[:3]
                if sc3 in lut:
                    dc3 = lut[sc3]
                else:
                    dc3 = nearest_lut(lut, sc3)
                    fallback_count += 1
                op[x, y] = dc3 + (sc[3],)
        out.save(os.path.join(ROOT, dst_path))
        print("converted", dst_path, "nearest-fallback px:", fallback_count)


def main():
    lut, votes, ambiguous = build_lut()
    print("lut colors:", len(lut), "| ambiguous:", len(ambiguous))
    convert(lut)
    convert_portraits()


if __name__ == "__main__":
    main()
