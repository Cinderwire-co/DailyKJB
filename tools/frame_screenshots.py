#!/usr/bin/env python3
"""App Store frames: a caption over each simulator screenshot, on parchment. See tools/screenshots.sh."""
import sys, os, numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
FONTS = os.path.join(ROOT, 'dailykjb', 'assets', 'fonts')
CAPS = os.path.join(FONTS, 'Cinzel-SemiBold.ttf'); SERIF = os.path.join(FONTS, 'EBGaramond-Italic.ttf')
GRAIN = os.path.join(ROOT, 'dailykjb', 'assets', 'images', 'paper_grain.png')

def background(W, H, dark):
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    r = np.clip(np.sqrt((x - W * .5) ** 2 + (y - H * .2) ** 2) / (max(W, H) * .9), 0, 1)[..., None]
    if dark: a, b = np.array([46, 36, 28]), np.array([22, 17, 13])
    else: a, b = np.array([248, 239, 222]), np.array([228, 206, 170])
    img = (a * (1 - r ** 1.4) + b * r ** 1.4).astype(np.uint8)
    im = Image.fromarray(img, 'RGB').convert('RGBA')
    g = Image.open(GRAIN).convert('RGBA'); g = g.resize((g.width * 3, g.height * 3))
    tile = Image.new('RGBA', (W, H))
    for yy in range(0, H, g.height):
        for xx in range(0, W, g.width): tile.paste(g, (xx, yy))
    col = (255, 233, 200) if dark else (110, 75, 42)
    alpha = np.array(tile.split()[3]).astype(np.float32) * (0.35 if dark else 0.6)
    layer = Image.new('RGBA', (W, H), col + (0,)); layer.putalpha(Image.fromarray(alpha.clip(0, 255).astype(np.uint8)))
    return Image.alpha_composite(im, layer)

def ornament(d, cx, y, w, col):
    d.line([(cx - w // 2, y), (cx - 26, y)], fill=col, width=3); d.line([(cx + 26, y), (cx + w // 2, y)], fill=col, width=3)
    d.polygon([(cx, y - 11), (cx + 11, y), (cx, y + 11), (cx - 11, y)], fill=col)
    for dx in (-19, 19): d.ellipse([cx + dx - 4, y - 4, cx + dx + 4, y + 4], fill=col)

def wrap(d, text, font, maxw):
    words, lines, cur = text.split(), [], ''
    for w in words:
        t = (cur + ' ' + w).strip()
        if d.textlength(t, font=font) <= maxw: cur = t
        else: lines.append(cur); cur = w
    lines.append(cur); return lines

def frame(shot, out, title, sub, W, H, dark=False, ipad=False):
    bg = background(W, H, dark); d = ImageDraw.Draw(bg)
    ink = (245, 236, 221) if dark else (42, 30, 21); faded = (200, 180, 155) if dark else (124, 104, 82)
    accent = (231, 155, 93) if dark else (192, 99, 43); gold = (216, 176, 106) if dark else (176, 131, 44)
    tsize = int(W * (0.058 if not ipad else 0.05)); ssize = int(W * (0.038 if not ipad else 0.031))
    tf = ImageFont.truetype(CAPS, tsize); sf = ImageFont.truetype(SERIF, ssize)
    top = int(H * 0.06); y = top
    for line in wrap(d, title.upper(), tf, W * 0.86):
        d.text((W / 2, y), line, font=tf, fill=ink, anchor='ma'); y += int(tsize * 1.22)
    y += int(tsize * .25); ornament(d, W // 2, y + 6, int(W * .22), gold); y += int(tsize * .7)
    for line in wrap(d, sub, sf, W * 0.8):
        d.text((W / 2, y), line, font=sf, fill=faded, anchor='ma'); y += int(ssize * 1.3)
    # The screen, rounded, with a shadow, filling the rest
    s = Image.open(shot).convert('RGBA')
    avail_h = H - y - int(H * 0.03) - 70; scale = min((W * (0.84 if not ipad else 0.8)) / s.width, avail_h / s.height)
    sw, sh = int(s.width * scale), int(s.height * scale); s = s.resize((sw, sh), Image.LANCZOS)
    rad = int(sw * (0.085 if not ipad else 0.035))
    mask = Image.new('L', (sw, sh), 0); ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw - 1, sh - 1], radius=rad, fill=255)
    x0 = (W - sw) // 2; y0 = H - sh - int(H * 0.03)
    shadow = Image.new('RGBA', (W, H), (0, 0, 0, 0)); ImageDraw.Draw(shadow).rounded_rectangle([x0, y0 + 18, x0 + sw, y0 + sh + 18], radius=rad, fill=(40, 20, 5, 120 if not dark else 200))
    bg = Image.alpha_composite(bg, shadow.filter(ImageFilter.GaussianBlur(36)))
    border = Image.new('RGBA', (W, H), (0, 0, 0, 0)); ImageDraw.Draw(border).rounded_rectangle([x0 - 10, y0 - 10, x0 + sw + 10, y0 + sh + 10], radius=rad + 10, fill=(64, 34, 20, 255) if not dark else (90, 66, 46, 255))
    bg = Image.alpha_composite(bg, border)
    bg.paste(s, (x0, y0), mask)
    bg.convert('RGB').save(out, quality=95)

CAPTIONS = [
    ('01-today', 'A little of the Word, every day', 'Reading plans for the whole Bible, in order or as it happened. Begin today.', False),
    ('02-bible', 'Turn the page, chapter to chapter', 'Swipe through the King James Bible. Tap verses to highlight, note, copy or share.', False),
    ('03-word', 'Back to the Hebrew and Greek', "Tap any word for Strong's and Webster's 1828, built in and working offline.", False),
    ('04-notes', 'Study notes, written on your iPhone', 'Apple Intelligence explains a verse privately, on the device, with no connection.', False),
    ('05-reading', "Today's chapters, one after another", 'Mark the day read, or take a short quiz on what you read.', False),
    ('06-journal', 'Everything you noted, in one place', 'Notes and highlights, searchable, a tap from where you wrote them.', False),
    ('07-progress', 'Watch the year take shape', 'Days read, days in a row, and every day of the plan on its calendar.', False),
    ('08-focus', 'The Word before the world', "Focus Mode keeps the apps you choose closed each day until you've read.", False),
    ('09-bible-dark', 'Parchment by day, lamplight by night', 'Light and dark, the type and size you like, a verse to a line or as a paragraph.', True),
    ('10-share', 'Share a verse as a picture', 'Square for a post, tall for a story, on paper, in ink or in ember.', False),
]

if __name__ == '__main__':
    # frame_screenshots.py <raw-dir> <iphone|ipad> <out-dir>
    raw, kind, out = sys.argv[1], sys.argv[2], sys.argv[3]
    ipad = kind == 'ipad'
    W, H = (2064, 2752) if ipad else (1320, 2868)
    os.makedirs(out, exist_ok=True)
    for name, title, sub, dark in CAPTIONS:
        shot = os.path.join(raw, name + '.png')
        if not os.path.exists(shot): continue
        dest = os.path.join(out, name + '.png')
        frame(shot, dest, title, sub, W, H, dark, ipad)
        Image.open(dest).convert('RGB').save(dest[:-4] + '.jpg', quality=92); os.remove(dest)
        print(dest[:-4] + '.jpg')
