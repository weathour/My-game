from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "baseline-source"
OUTPUT = ROOT / "current-feedback-contact-sheet.png"
SAMPLES = [
    ("B01 confirmed hit", "B01-confirmed-hit.png"),
    ("B01 shield guard", "B01-full-shield-guard.png"),
    ("B01 enemy tell / party", "B01-comfort-tell.png"),
    ("B01 XP pickup", "B01-xp-pickup.png"),
    ("B15 dense 42-target cast", "B15-42-target-cast.png"),
    ("B18 boss priority", "B18-boss-priority.png"),
]

cell_w, cell_h, label_h = 640, 360, 38
sheet = Image.new("RGB", (cell_w * 2, (cell_h + label_h) * 3), "#151713")
draw = ImageDraw.Draw(sheet)
font = ImageFont.load_default(size=20)
for index, (label, filename) in enumerate(SAMPLES):
    image = Image.open(SOURCE / filename).convert("RGB")
    image = image.resize((cell_w, cell_h), Image.Resampling.LANCZOS)
    x, y = (index % 2) * cell_w, (index // 2) * (cell_h + label_h)
    sheet.paste(image, (x, y + label_h))
    draw.rectangle((x, y, x + cell_w - 1, y + label_h - 1), fill="#252a25")
    draw.text((x + 12, y + 9), label, fill="#f2e8cb", font=font)
sheet.save(OUTPUT)
print(OUTPUT)
