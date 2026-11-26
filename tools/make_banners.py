#!/usr/bin/env python3
"""The product page's header and search results art (App Store Connect > the version > Product Page Information >
Header and Search Results), from the raw iPhone captures:

  header-3840x1646.png       21:9 header
  search-3840x2560.png       3:2 search results
  universal-5244x2950.png    16:9, accepted for both
  play-feature-1024x500.png  Google Play's feature graphic (with an Android raw folder)

  tools/.venv/bin/python tools/make_banners.py <raw-iphone-dir> [<raw-android-dir>]

The raw folder is tools/screenshots.sh's iPhone 6.9" output, with shield.png from tools/shield_shot.swift.
They lead with what Daily KJB is: an accountability Bible reading app.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from frame_screenshots import CAPS, SERIF, background, device, ornament, wrap  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
OUT = os.path.join(ROOT, 'store', 'marketing')
INK, FADED, ACCENT, GOLD = (42, 30, 21), (124, 104, 82), (192, 99, 43), (176, 131, 44)

EYEBROW = 'An accountability Bible reading app'
HEADLINE = 'The Word first.'
SUB = "Your chosen apps stay locked each day until you've read. The King James Bible, reading plans and word study, offline and private."


def phone(path, width, android=False):
    """A screen in its phone (an iPhone's Dynamic Island, or an Android's camera), with its shadow."""
    dev, rim = device(path, width, android=android)
    pad = int(width * 0.18)
    out = Image.new('RGBA', (dev.width + 2 * pad, dev.height + 2 * pad), (0, 0, 0, 0))
    shadow = Image.new('RGBA', out.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [pad, pad + width // 25, pad + dev.width, pad + dev.height + width // 25],
        radius=int(width * 0.128) + rim, fill=(50, 25, 8, 120))
    out = Image.alpha_composite(out, shadow.filter(ImageFilter.GaussianBlur(width // 14)))
    out.alpha_composite(dev, (pad, pad))
    return out, pad


def place(canvas, item, x, y):
    img, pad = item
    canvas.alpha_composite(img, (int(x - pad), int(y - pad)))


def text_block(canvas, x, y, max_w, scale, center=False):
    """Eyebrow, headline, ornament, line under it; returns the bottom."""
    d = ImageDraw.Draw(canvas)
    eb = ImageFont.truetype(CAPS, int(56 * scale))
    hl = ImageFont.truetype(CAPS, int(190 * scale))
    sb = ImageFont.truetype(SERIF, int(80 * scale))
    anchor = 'ma' if center else 'la'
    d.text((x, y), EYEBROW.upper(), font=eb, fill=ACCENT, anchor=anchor)
    y += int(56 * scale * 1.9)
    for line in wrap(d, HEADLINE, hl, max_w):
        d.text((x, y), line, font=hl, fill=INK, anchor=anchor)
        y += int(190 * scale * 1.1)
    y += int(40 * scale)
    ox = x if center else x + int(150 * scale)
    ornament(d, int(ox), y, int(300 * scale), GOLD)
    y += int(70 * scale)
    for line in wrap(d, SUB, sb, max_w):
        d.text((x, y), line, font=sb, fill=FADED, anchor=anchor)
        y += int(80 * scale * 1.32)
    return y


def side_by_side(W, H, raw, scale, phone_w):
    """Words on the left, the shield in front of Today on the right."""
    c = background(W, H, False)
    text_block(c, int(W * 0.08), int(H * 0.27), int(W * 0.44), scale)
    back = phone(os.path.join(raw, '01-today.png'), phone_w)
    front = phone(os.path.join(raw, 'shield.png'), phone_w)
    ph = back[0].height - 2 * back[1]
    # Both well inside the frame, so a cropped header still shows them whole
    place(c, back, W * 0.58, H * 0.5 - ph * 0.5 - H * 0.035)
    place(c, front, W * 0.58 + phone_w * 0.8, H * 0.5 - ph * 0.5 + H * 0.035)
    return c


def header(raw):
    W, H = 3840, 1646
    c = side_by_side(W, H, raw, 1.0, 500)
    return c.crop((0, 0, W, H))


def universal(raw):
    W, H = 5244, 2950
    return side_by_side(W, H, raw, 1.45, 880)


def search(raw):
    """Words across the top, then the shield, Today and the end of the day's reading."""
    W, H = 3840, 2560
    c = background(W, H, False)
    bottom = text_block(c, W // 2, int(H * 0.07), int(W * 0.8), 1.0, center=True)
    phone_w = 640
    shots = ['shield.png', '01-today.png', '05-reading.png']
    gap = 150
    total = len(shots) * phone_w + (len(shots) - 1) * gap
    x = (W - total) // 2
    for i, s in enumerate(shots):
        place(c, phone(os.path.join(raw, s), phone_w), x + i * (phone_w + gap), bottom + 60 + (0 if i == 1 else 50))
    return c


def play_feature(raw):
    """Google Play's 1024 x 500 feature graphic: the words, and the Android shield over a locked app."""
    W, H = 1024, 500
    c = background(W, H, False)
    d = ImageDraw.Draw(c)
    eb = ImageFont.truetype(CAPS, 17)
    hl = ImageFont.truetype(CAPS, 54)
    sb = ImageFont.truetype(SERIF, 22)
    x, y = 56, 150
    d.text((x, y), EYEBROW.upper(), font=eb, fill=ACCENT)
    d.text((x, y + 34), HEADLINE, font=hl, fill=INK)
    ornament(d, x + 45, y + 112, 90, GOLD)
    for i, line in enumerate(wrap(d, "Your chosen apps stay locked each day until you've read.", sb, 520)):
        d.text((x, y + 134 + i * 30), line, font=sb, fill=FADED)
    for name, px, py in [('01-today.png', 650, 70), ('shield.png', 790, 110)]:
        place(c, phone(os.path.join(raw, name), 170, android=True), px, py)
    return c


if __name__ == '__main__':
    raw = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    for name, make in [('header-3840x1646.png', header), ('search-3840x2560.png', search),
                       ('universal-5244x2950.png', universal)]:
        path = os.path.join(OUT, name)
        make(raw).convert('RGB').save(path, optimize=True)
        print(os.path.relpath(path, ROOT))
    if len(sys.argv) > 2:
        path = os.path.join(OUT, 'play-feature-1024x500.png')
        play_feature(sys.argv[2]).convert('RGB').save(path, optimize=True)
        print(os.path.relpath(path, ROOT))
