"""Draw a Zoo - 512x512 icons for the game passes and developer products. Run: python make_pass_icons.py
Bold cartoon style to match the HUD: gradient tile, thick black outline, chunky label with a dark stroke."""
import os
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "export", "icons")
FONT = r"C:\Windows\Fonts\ariblk.ttf"
N = 512

# name: (top colour, bottom colour, big text, small text)
ICONS = {
    "VIP": ("FFD54A", "F28A00", "VIP", "+20% CASH"),
    "Money2x": ("8CF27A", "1FA34A", "x2", "MONEY"),
    "Luck2x": ("8FE3FF", "2F7BE0", "x2", "LUCK"),
    "LuckBoost": ("D9A6FF", "7A3FD6", "x2", "LUCK 5 MIN"),
    "StarterPack": ("FFB38A", "E0482F", "START", "PACK"),
    "OfflineDouble": ("A8B8FF", "4650C8", "x2", "OFFLINE"),
}


def hexrgb(h): return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def icon(top, bottom, big, small):
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    grad = Image.new("RGBA", (N, N))
    a, b = hexrgb(top), hexrgb(bottom)
    for y in range(N):
        t = y / (N - 1)
        ImageDraw.Draw(grad).line([(0, y), (N, y)], fill=tuple(round(a[k] + (b[k] - a[k]) * t) for k in range(3)) + (255,))
    mask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(mask).rounded_rectangle([20, 20, N - 21, N - 21], 90, fill=255)
    im.paste(grad, (0, 0), mask)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([20, 20, N - 21, N - 21], 90, outline=(20, 20, 24, 255), width=16)
    gloss = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(gloss).rounded_rectangle([64, 50, N - 65, 112], 30, fill=(255, 255, 255, 60))
    im.alpha_composite(gloss)   # blended glossy highlight (drawing straight onto RGBA would replace, not blend)
    d = ImageDraw.Draw(im)
    for text, size, cy in ((big, 210 if len(big) <= 3 else 118, 230), (small, 64 if len(small) <= 7 else 48, 390)):
        f = ImageFont.truetype(FONT, size)
        d.text((N / 2, cy), text, font=f, anchor="mm", fill=(255, 255, 255, 255), stroke_width=max(8, size // 14), stroke_fill=(20, 20, 24, 255))
    return im


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, spec in ICONS.items():
        icon(*spec).save(os.path.join(OUT, name + ".png"))
    assert all(Image.open(os.path.join(OUT, n + ".png")).size == (N, N) for n in ICONS)   # self-check
    print("wrote", len(ICONS), "icons to", OUT)
