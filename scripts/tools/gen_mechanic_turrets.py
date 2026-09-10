#!/usr/bin/env python3
"""Generate mechanical turret pixel art for the mechanic role.

Draws at a small native resolution and upscales with NEAREST into the
256x256 canvases the abilities expect, so the existing scale constants
keep working. Outputs:
  effects/mechanic/tulip_turret/1-3.png   (small turret, faces right)
  effects/mechanic/heavy_cannon/1-3.png   (heavy cannon, faces right)
  effects/mechanic/field_tower/1-3.png    (pylon, looping pulse)
"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
NATIVE = 64
CANVAS = 256
SCALE = CANVAS // NATIVE

OUTLINE = (22, 18, 30, 255)
STEEL_DARK = (58, 66, 84, 255)
STEEL_MID = (110, 124, 148, 255)
STEEL_LIGHT = (168, 182, 204, 255)
STEEL_HI = (226, 234, 244, 255)
AMBER = (242, 169, 59, 255)
AMBER_LIGHT = (255, 210, 122, 255)
AMBER_DARK = (176, 106, 26, 255)
FLASH_CORE = (255, 246, 190, 255)
FLASH_MID = (255, 201, 77, 255)
FLASH_OUT = (242, 140, 40, 255)
CYAN_CORE = (210, 240, 255, 255)
CYAN_MID = (140, 205, 250, 255)
CYAN_DARK = (70, 130, 190, 255)


def new_img():
    img = Image.new("RGBA", (NATIVE, NATIVE), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def poly(d, pts, fill, outline=OUTLINE):
    d.polygon(pts, fill=fill, outline=outline)


def rect(d, x0, y0, x1, y1, fill, outline=None):
    d.rectangle([x0, y0, x1, y1], fill=fill, outline=outline)


def px(d, x, y, c):
    d.point((x, y), fill=c)


def ellipse(d, x0, y0, x1, y1, fill, outline=None):
    d.ellipse([x0, y0, x1, y1], fill=fill, outline=outline)


def shaded_dome(d, cx, cy, rx, ry):
    """Armored dome with light from upper-left."""
    ellipse(d, cx - rx, cy - ry, cx + rx, cy + ry, STEEL_MID, OUTLINE)
    ellipse(d, cx - rx + 3, cy - ry + 2, cx + rx - 2, cy + ry - 3, STEEL_LIGHT)
    ellipse(d, cx - rx + 5, cy - ry + 3, cx + rx - 8, cy + ry - 7, STEEL_HI)
    rect(d, cx - rx + 2, cy + ry - 5, cx + rx - 2, cy + ry - 1, STEEL_DARK)


def muzzle_flash(d, x, y, r):
    """4-point star muzzle flash at (x, y)."""
    pts = []
    import math
    for i in range(8):
        ang = math.pi * i / 4.0
        rad = r if i % 2 == 0 else r * 0.4
        pts.append((x + rad * math.cos(ang), y + rad * math.sin(ang)))
    poly(d, pts, FLASH_OUT, None)
    pts2 = []
    for i in range(8):
        ang = math.pi * i / 4.0
        rad = r * 0.66 if i % 2 == 0 else r * 0.26
        pts2.append((x + rad * math.cos(ang), y + rad * math.sin(ang)))
    poly(d, pts2, FLASH_MID, None)
    ellipse(d, x - r * 0.2, y - r * 0.2, x + r * 0.2, y + r * 0.2, FLASH_CORE)


def save(img, path):
    big = img.resize((CANVAS, CANVAS), Image.NEAREST)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    big.save(path)


# ---------------------------------------------------------------- small turret
def small_turret(frame):
    """Armored dome on tripod, single barrel facing right."""
    img, d = new_img()
    recoil = 1 if frame == 2 else 0
    # tripod legs
    for lx, ly0, ly1 in [(18, 46, 58), (30, 48, 59), (42, 46, 58)]:
        d.line([lx, ly0, lx - 3, ly1], fill=OUTLINE, width=3)
        d.line([lx, ly0, lx - 3, ly1], fill=STEEL_DARK, width=1)
        rect(d, lx - 6, ly1, lx, ly1 + 2, OUTLINE)  # foot
    # base plate
    poly(d, [(14, 42), (46, 42), (50, 50), (10, 50)], STEEL_DARK)
    rect(d, 16, 43, 44, 45, STEEL_MID)
    # dome body
    bx = 30 - recoil
    shaded_dome(d, bx, 34, 13, 11)
    # amber stripe on dome
    rect(d, bx - 10, 30, bx + 9, 33, AMBER)
    rect(d, bx - 10, 30, bx + 9, 31, AMBER_LIGHT)
    # barrel (two-tone, with muzzle ring)
    by = 28
    rect(d, bx + 6 - recoil, by - 3, bx + 26 - recoil, by + 3, STEEL_MID, OUTLINE)
    rect(d, bx + 7 - recoil, by - 2, bx + 25 - recoil, by - 1, STEEL_LIGHT)
    rect(d, bx + 21 - recoil, by - 5, bx + 27 - recoil, by + 5, STEEL_DARK, OUTLINE)  # muzzle brake
    rect(d, bx + 22 - recoil, by - 4, bx + 26 - recoil, by - 3, STEEL_MID)
    # amber core lamp on dome top
    rect(d, bx - 2, 21, bx + 2, 24, AMBER, OUTLINE)
    px(d, bx - 1, 22, AMBER_LIGHT)
    if frame == 2:
        muzzle_flash(d, bx + 33, by, 9)
    elif frame == 3:
        # dissipating smoke dot
        ellipse(d, bx + 30, by - 2, bx + 36, by + 4, (200, 200, 210, 160))
    return img


# ---------------------------------------------------------------- heavy cannon
def heavy_cannon(frame):
    """Wide siege cannon: treaded base, twin barrels, hazard stripes."""
    img, d = new_img()
    recoil = 2 if frame == 2 else 0
    # treads
    rect(d, 6, 50, 58, 60, OUTLINE)
    rect(d, 8, 52, 56, 58, STEEL_DARK)
    for wx in range(12, 56, 8):
        ellipse(d, wx - 3, 51, wx + 3, 59, STEEL_MID, OUTLINE)
        px(d, wx, 55, STEEL_HI)
    # armored hull (sloped front)
    hx = 2 - recoil
    poly(d, [(8 + hx, 50), (56 + hx, 50), (52 + hx, 34), (14 + hx, 30)], STEEL_MID)
    poly(d, [(12 + hx, 48), (52 + hx, 48), (50 + hx, 40), (15 + hx, 37)], STEEL_LIGHT)
    # hazard stripes on hull
    for sx in range(16 + hx, 44 + hx, 8):
        poly(d, [(sx, 44), (sx + 4, 44), (sx + 1, 48), (sx - 3, 48)], AMBER)
    # rear ammo box
    rect(d, 6 + hx, 24, 16 + hx, 36, STEEL_DARK, OUTLINE)
    rect(d, 8 + hx, 26, 14 + hx, 28, AMBER_DARK)
    # twin barrels
    for by in (24, 32):
        rect(d, 20 + hx - recoil, by - 3, 52 + hx - recoil, by + 3, STEEL_MID, OUTLINE)
        rect(d, 21 + hx - recoil, by - 2, 51 + hx - recoil, by - 1, STEEL_LIGHT)
        rect(d, 46 + hx - recoil, by - 5, 54 + hx - recoil, by + 5, STEEL_DARK, OUTLINE)  # brake
        rect(d, 47 + hx - recoil, by - 4, 53 + hx - recoil, by - 3, STEEL_MID)
    #炮闩 amber core between barrels
    rect(d, 22 + hx, 26, 28 + hx, 30, AMBER, OUTLINE)
    px(d, 24 + hx, 27, AMBER_LIGHT)
    if frame == 2:
        muzzle_flash(d, 58, 24, 8)
        muzzle_flash(d, 58, 32, 8)
    elif frame == 3:
        ellipse(d, 54, 22, 60, 28, (200, 200, 210, 150))
        ellipse(d, 54, 30, 60, 36, (200, 200, 210, 150))
    return img


# ---------------------------------------------------------------- field tower
def field_tower(frame):
    """Tesla-like pylon with coil rings and a pulsing orb. Neutral steel;
    the ability tints it cyan via modulate."""
    img, d = new_img()
    glow = [0.35, 0.7, 1.0][frame - 1]
    # tripod legs
    for lx, ly0, ly1 in [(22, 44, 58), (32, 46, 59), (42, 44, 58)]:
        d.line([lx, ly0, lx - 3, ly1], fill=OUTLINE, width=3)
        d.line([lx, ly0, lx - 3, ly1], fill=STEEL_DARK, width=1)
        rect(d, lx - 6, ly1, lx, ly1 + 2, OUTLINE)
    # base plate
    poly(d, [(20, 40), (44, 40), (48, 48), (16, 48)], STEEL_DARK)
    rect(d, 22, 41, 42, 43, STEEL_MID)
    # column
    rect(d, 28, 18, 36, 42, STEEL_MID, OUTLINE)
    rect(d, 29, 19, 31, 41, STEEL_LIGHT)
    # coil rings
    for ry in (24, 31, 38):
        rect(d, 24, ry - 1, 40, ry + 1, STEEL_DARK, OUTLINE)
        rect(d, 25, ry - 1, 39, ry, STEEL_HI)
    # orb on top
    ellipse(d, 26, 6, 38, 18, CYAN_DARK, OUTLINE)
    ellipse(d, 28, 8, 36, 16, CYAN_MID)
    ellipse(d, 29, 9, 34, 13, CYAN_CORE)
    # glow halo scales with frame
    halo_r = int(6 + glow * 5)
    halo_a = int(40 + glow * 90)
    for i in range(halo_r, 0, -2):
        a = int(halo_a * (1.0 - i / (halo_r + 1)))
        d.ellipse([32 - 4 - i, 12 - 4 - i, 32 + 4 + i, 12 + 4 + i], outline=(150, 215, 255, a))
    # sparks on coil for brightest frame
    if frame == 3:
        for sx, sy in [(24, 22), (40, 29), (25, 37), (39, 20)]:
            d.line([sx - 2, sy, sx + 2, sy], fill=CYAN_CORE, width=1)
            d.line([sx, sy - 2, sx, sy + 2], fill=CYAN_CORE, width=1)
    return img


def main():
    groups = {
        "tulip_turret": small_turret,
        "heavy_cannon": heavy_cannon,
        "field_tower": field_tower,
    }
    for name, fn in groups.items():
        for frame in (1, 2, 3):
            out = os.path.join(ROOT, "effects", "mechanic", name, "%d.png" % frame)
            save(fn(frame), out)
            print("wrote", out)


if __name__ == "__main__":
    main()
