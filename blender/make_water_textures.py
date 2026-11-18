"""Draw a Zoo - waterfall textures (run with plain Python + Pillow). Writes into blender/export/:
  WaterfallBody.png   soft, wavy light bands that give the back of the water sheet some body (tiles both ways)
  WaterfallWisps.png  thin, tapered, slightly wavy streaks with soft edges (tiles both ways)
  FoamPuffs.png       2x2 flipbook of lumpy cartoon foam clusters, one picked per particle
  Droplets.png        2x2 flipbook of droplet shapes (teardrop, pair, cluster, splat)
A Beam lays an image's HEIGHT along its length, so everything that flows is drawn vertically.
"""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "export")


def body(W=256, H=512):
    img = Image.new("RGBA", (W, H))
    px = img.load()
    rnd = random.Random(11)
    # integer frequencies keep it seamless; tall waves (low ky) make the bands run down the fall
    waves = [(rnd.randint(2, 7), rnd.randint(1, 2), rnd.uniform(0, 6.28), rnd.uniform(0.5, 1.0)) for _ in range(7)]
    tot = sum(w[3] for w in waves)
    for y in range(H):
        for x in range(W):
            v = sum(a * math.sin(2 * math.pi * (kx * x / W + ky * y / H) + ph) for kx, ky, ph, a in waves) / tot
            v = 0.5 + 0.5 * v
            v = v * v * (3 - 2 * v)                       # smoothstep: crisper cartoon bands
            px[x, y] = (255, 255, 255, int(25 + 170 * v))
    return img


def wisps(W=128, H=512):
    img = Image.new("RGBA", (W, H), (255, 255, 255, 0))
    rnd = random.Random(5)
    K = 4                                                  # drawn 4x larger, then scaled down: smooth edges
    layer = Image.new("L", (W * K, H * K), 0)
    d = ImageDraw.Draw(layer)
    for _ in range(30):
        x0, y0 = rnd.uniform(0, W), rnd.uniform(0, H)
        L, w, a = rnd.uniform(110, 320), rnd.uniform(1.2, 4.0), rnd.randint(120, 255)
        amp, ph = rnd.uniform(0.6, 2.2), rnd.uniform(0, 6.28)
        n = 40
        for i in range(n):
            t0, t1 = i / n, (i + 1) / n
            taper = math.sin(math.pi * (t0 + t1) / 2) ** 0.7   # thin at both ends: a wisp, not a dash
            pts = [(x0 + amp * math.sin(ph + t * 5.0), y0 + t * L) for t in (t0, t1)]
            for dx in (0, -W, W):
                for dy in (0, -H):
                    d.line([((x + dx) * K, (y + dy) * K) for x, y in pts], fill=int(a * (0.3 + 0.7 * taper)),
                           width=max(1, int(2 * w * taper * K)), joint="curve")
    layer = layer.resize((W, H), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.6))
    img.putalpha(layer)
    return img


def blob_cell(rnd, S, kind):
    cell = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(cell)
    c = S / 2
    if kind == "foam":
        for _ in range(rnd.randint(5, 9)):                 # lumpy cluster of circles = one cartoon foam puff
            a, rr = rnd.uniform(0, 6.28), rnd.uniform(0, S * 0.2)
            r = rnd.uniform(S * 0.12, S * 0.22)
            x, y = c + rr * math.cos(a), c + rr * math.sin(a) * 0.8
            d.ellipse((x - r, y - r, x + r, y + r), fill=255)
        for _ in range(rnd.randint(2, 4)):                 # a few loose bubbles
            a, rr, r = rnd.uniform(0, 6.28), rnd.uniform(S * 0.3, S * 0.4), rnd.uniform(S * 0.03, S * 0.06)
            x, y = c + rr * math.cos(a), c + rr * math.sin(a)
            d.ellipse((x - r, y - r, x + r, y + r), fill=230)
    return cell


def foam(S=256):
    rnd = random.Random(21)
    sheet = Image.new("RGBA", (2 * S, 2 * S), (255, 255, 255, 0))
    for k in range(4):
        a = blob_cell(rnd, S, "foam").filter(ImageFilter.GaussianBlur(2.5))
        # light blue shade on the lower side so each puff reads as a rounded lump
        tile = Image.new("RGBA", (S, S))
        tp = tile.load(); ap = a.load()
        for y in range(S):
            shade = max(0.0, (y / S - 0.45) * 1.4)
            col = (int(255 - 40 * shade), int(255 - 18 * shade), 255)
            for x in range(S):
                tp[x, y] = (*col, ap[x, y])
        sheet.paste(tile, ((k % 2) * S, (k // 2) * S))
    return sheet


def droplets(S=128):
    sheet = Image.new("RGBA", (2 * S, 2 * S), (255, 255, 255, 0))
    def drop(d, x, y, r):                                  # teardrop pointing up (particles align it to their motion)
        d.ellipse((x - r, y - r, x + r, y + r), fill=255)
        d.polygon([(x - r * 0.92, y - r * 0.35), (x, y - r * 2.6), (x + r * 0.92, y - r * 0.35)], fill=255)
    layouts = [[(64, 78, 22)], [(48, 84, 17), (84, 62, 11)], [(64, 80, 13), (40, 58, 8), (88, 50, 9), (70, 34, 6)], None]
    for k, lay in enumerate(layouts):
        cell = Image.new("L", (S, S), 0)
        d = ImageDraw.Draw(cell)
        if lay is None:                                    # small splat: a crown of dots around a blob
            d.ellipse((46, 46, 82, 82), fill=255)
            for i in range(7):
                a = i / 7 * 6.28
                x, y, r = 64 + 34 * math.cos(a), 64 + 34 * math.sin(a), 6
                d.ellipse((x - r, y - r, x + r, y + r), fill=255)
        else:
            for x, y, r in lay: drop(d, x, y, r)
        cell = cell.filter(ImageFilter.GaussianBlur(1.2))
        tile = Image.new("RGBA", (S, S), (255, 255, 255, 0)); tile.putalpha(cell)
        sheet.paste(tile, ((k % 2) * S, (k // 2) * S))
    return sheet


if __name__ == "__main__":
    for name, img in (("WaterfallBody", body()), ("WaterfallWisps", wisps()), ("FoamPuffs", foam()), ("Droplets", droplets())):
        img.save(os.path.join(OUT, name + ".png"))
        a = img.getchannel("A")
        assert a.getextrema()[1] > 150, name           # self-check: every texture has visible content
        print(name, img.size)
