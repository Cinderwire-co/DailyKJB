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

def device(shot, width, ipad=False, android=False):
    """The screen in an iPhone (or iPad, or Android phone) as it looks: a black bezel with a thin metal edge, the
    display's rounded corners and, on iPhone, the Dynamic Island, which simulator captures leave out (Apple's sizes, in
    points: 126 x 37, 11 from the top); on Android, the punch-hole camera. Returns the image and how far the screen
    sits inside it."""
    s = shot if isinstance(shot, Image.Image) else Image.open(shot).convert('RGBA')
    pts = s.width / (2 if ipad else 2.625 if android else 3)  # the display's width in points (dp on Android)
    k = width / pts  # pixels per point here
    h = int(s.height * width / s.width)
    s = s.resize((width, h), Image.LANCZOS)
    rad = int(width * (0.128 if not ipad else 0.03))
    bezel = max(6, int((9 if not ipad else 18) * k))
    edge = max(2, int(2.5 * k))
    rim = bezel + edge
    out = Image.new('RGBA', (width + 2 * rim, h + 2 * rim), (0, 0, 0, 0))
    d = ImageDraw.Draw(out)
    d.rounded_rectangle([0, 0, out.width - 1, out.height - 1], radius=rad + rim, fill=(58, 58, 62, 255))
    d.rounded_rectangle([edge, edge, out.width - 1 - edge, out.height - 1 - edge], radius=rad + bezel, fill=(8, 8, 10, 255))
    mask = Image.new('L', (width, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, width - 1, h - 1], radius=rad, fill=255)
    out.paste(s, (rim, rim), mask)
    if android:
        r, top = 12 * k, 12 * k
        cx = rim + width / 2
        d.ellipse([cx - r, rim + top, cx + r, rim + top + 2 * r], fill=(0, 0, 0, 255))
    elif not ipad:
        iw, ih, top = 126 * k, 37 * k, 11 * k
        cx = rim + width / 2
        d.rounded_rectangle([cx - iw / 2, rim + top, cx + iw / 2, rim + top + ih], radius=ih / 2, fill=(0, 0, 0, 255))
    return out, rim


def frame(shot, out, title, sub, W, H, dark=False, ipad=False, android=False):
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
    # The device, with a shadow, filling the rest
    s = Image.open(shot).convert('RGBA')
    avail_h = H - y - int(H * 0.03) - 70
    sw = int(min(W * (0.80 if not ipad else 0.78), avail_h * s.width / s.height))
    dev, rim = device(s, sw, ipad, android)
    x0 = (W - dev.width) // 2; y0 = H - dev.height - int(H * 0.025)
    rad = int(sw * (0.128 if not ipad else 0.03))
    shadow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([x0, y0 + 18, x0 + dev.width, y0 + dev.height + 18], radius=rad + rim, fill=(40, 20, 5, 120 if not dark else 200))
    bg = Image.alpha_composite(bg, shadow.filter(ImageFilter.GaussianBlur(36)))
    bg.alpha_composite(dev, (x0, y0))
    bg.convert('RGB').save(out, quality=95)

# (file in the store, raw capture it frames, caption, line under it, dark)
# Accountability first: the first three show in App Store search results.
CAPTIONS = [
    ('01-focus', '08-focus', 'An accountability Bible reading app', "Choose the apps that pull you away. Each day they stay locked until you've read.", False),
    ('02-shield', 'shield', 'Your Bible before your apps', "Open a locked app and Read now takes you straight to today's chapters.", False),
    ('03-today', '01-today', 'A little of the Word, every day', 'Reading plans for the whole Bible, in order or as it happened.', False),
    ('04-reading', '05-reading', 'Read it, or prove it', 'Mark the day read, or pass a short quiz on what you read. Then your apps open.', False),
    ('05-bible', '02-bible', 'Turn the page, chapter to chapter', 'Swipe through the King James Bible. Tap verses to highlight, note, copy or share.', False),
    ('06-word', '03-word', 'Back to the Hebrew and Greek', "Tap any word for Strong's and Webster's 1828, built in and working offline.", False),
    ('07-notes', '04-notes', 'Study notes, written on your iPhone', 'Apple Intelligence explains a verse privately, on the device, with no connection.', False),
    ('08-progress', '07-progress', 'Watch the year take shape', 'Days read, days in a row, and every day of the plan on its calendar.', False),
    ('09-bible-dark', '09-bible-dark', 'Parchment by day, lamplight by night', 'Light and dark, the type and size you like, a verse to a line or as a paragraph.', True),
    ('10-journal', '06-journal', 'Everything you noted, in one place', 'Notes and highlights, searchable, a tap from where you wrote them.', False),
]

if __name__ == '__main__':
    # frame_screenshots.py <raw-dir> <iphone|iphone-6.3|ipad|android> <out-dir>
    raw, kind, out = sys.argv[1], sys.argv[2], sys.argv[3]
    ipad = kind == 'ipad'
    W, H = {'ipad': (2064, 2752), 'iphone-6.3': (1206, 2622), 'android': (1080, 1920)}.get(kind, (1320, 2868))
    android = kind == 'android'  # Google Play: 9:16, an Android phone
    os.makedirs(out, exist_ok=True)
    made = 0
    for name, source, title, sub, dark in CAPTIONS:
        shot = os.path.join(raw, source + '.png')
        if not os.path.exists(shot) or (android and made == 8): continue  # Google Play takes eight
        made += 1
        dest = os.path.join(out, name + '.png')
        if android:
            sub = sub.replace('on your iPhone', 'on your phone')
        frame(shot, dest, title, sub, W, H, dark, ipad, android)
        Image.open(dest).convert('RGB').save(dest[:-4] + '.jpg', quality=92); os.remove(dest)
        print(dest[:-4] + '.jpg')
