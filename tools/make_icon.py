#!/usr/bin/env python3
"""Draws the app icon: a leather Bible on parchment with a burnt-orange cross.

  tools/.venv/bin/python tools/make_icon.py

Writes dailykjb/assets/dailykjb_app_icon.png (1024 square) and icon.png; then
`cd dailykjb && dart run flutter_launcher_icons` makes every size.
"""
import os
import numpy as np, sys
from PIL import Image, ImageDraw, ImageFilter
S = 4096; F = S / 1024
def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))
# Parchment: warm radial light
y, x = np.mgrid[0:S, 0:S].astype(np.float32)
r = np.sqrt((x - S * .5) ** 2 + (y - S * .42) ** 2) / (S * .75)
r = np.clip(r, 0, 1)[..., None]
c0 = np.array([248, 238, 219], np.float32); c1 = np.array([226, 200, 160], np.float32)
bg = c0 * (1 - r ** 1.6) + c1 * (r ** 1.6)
rng = np.random.default_rng(7)
noise = rng.standard_normal((S // 4, S // 4)).astype(np.float32)
noise = np.array(Image.fromarray(((noise * 18) + 128).clip(0, 255).astype(np.uint8)).resize((S, S), Image.BICUBIC)).astype(np.float32) - 128
bg = np.clip(bg + noise[..., None] * .35, 0, 255).astype(np.uint8)
img = Image.fromarray(bg, 'RGB').convert('RGBA')

def rr(box, rad, fill, im=None):
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle([int(v * F) for v in box], radius=int(rad * F), fill=fill)
    return layer

# Shadow under the book
sh = rr((270, 250, 790, 860), 46, (60, 30, 10, 150)).filter(ImageFilter.GaussianBlur(40 * F))
off = Image.new('RGBA', (S, S), (0, 0, 0, 0)); off.paste(sh, (int(18 * F), int(34 * F)), sh)
img = Image.alpha_composite(img, off)
# Page block (right and bottom edges)
img = Image.alpha_composite(img, rr((300, 210, 790, 840), 38, (120, 60, 30, 255)))
pages = rr((312, 222, 772, 822), 30, (244, 232, 206, 255))
img = Image.alpha_composite(img, pages)
d = ImageDraw.Draw(img)
for i in range(9):
    yy = int((812 - i * 4.5) * F)
    d.line([(int(330 * F), yy), (int(760 * F), yy)], fill=(214, 196, 160, 255), width=int(1.6 * F))
for i in range(9):
    xx = int((762 - i * 4.5) * F)
    d.line([(xx, int(240 * F)), (xx, int(800 * F))], fill=(214, 196, 160, 255), width=int(1.6 * F))
# Cover: leather, a vertical gradient
cover_mask = rr((250, 180, 740, 800), 40, (255, 255, 255, 255)).split()[3]
grad = np.zeros((S, S, 4), np.uint8)
t = np.clip((y - 180 * F) / (620 * F), 0, 1)[..., None]
top = np.array([150, 62, 34], np.float32); bot = np.array([92, 32, 18], np.float32)
grad[..., :3] = (top * (1 - t) + bot * t).astype(np.uint8)
grad[..., 3] = 255
leather = Image.fromarray(grad, 'RGBA')
ln = rng.standard_normal((S // 8, S // 8)).astype(np.float32)
ln = np.array(Image.fromarray(((ln * 30) + 128).clip(0, 255).astype(np.uint8)).resize((S, S), Image.BICUBIC)).astype(np.float32) - 128
la = np.array(leather).astype(np.float32); la[..., :3] = np.clip(la[..., :3] + ln[..., None] * .25, 0, 255)
leather = Image.fromarray(la.astype(np.uint8), 'RGBA')
img.paste(leather, (0, 0), cover_mask)
d = ImageDraw.Draw(img)
# Spine with raised bands
spine = rr((250, 180, 330, 800), 40, (70, 24, 12, 120))
img = Image.alpha_composite(img, spine)
d = ImageDraw.Draw(img)
for yy in (260, 340, 640, 720):
    d.rounded_rectangle([int(256 * F), int(yy * F), int(326 * F), int((yy + 14) * F)], radius=int(6 * F), fill=(176, 92, 52, 255))
d.line([(int(334 * F), int(196 * F)), (int(334 * F), int(784 * F))], fill=(58, 18, 8, 255), width=int(5 * F))
# Gilt border on the cover
d.rounded_rectangle([int(360 * F), int(214 * F), int(708 * F), int(766 * F)], radius=int(16 * F), outline=(226, 160, 92, 255), width=int(5 * F))
# Cross, burnt orange to gold, with a soft glow
glow = Image.new('RGBA', (S, S), (0, 0, 0, 0)); g = ImageDraw.Draw(glow)
cx, cy = 534, 470
def cross(dr, col, grow=0):
    dr.rounded_rectangle([int((cx - 23 - grow) * F), int((cy - 175 - grow) * F), int((cx + 23 + grow) * F), int((cy + 205 + grow) * F)], radius=int(8 * F), fill=col)
    dr.rounded_rectangle([int((cx - 118 - grow) * F), int((cy - 82 - grow) * F), int((cx + 118 + grow) * F), int((cy - 36 + grow) * F)], radius=int(8 * F), fill=col)
cross(g, (255, 170, 90, 150), 6)
glow = glow.filter(ImageFilter.GaussianBlur(26 * F))
img = Image.alpha_composite(img, glow)
cm = Image.new('L', (S, S), 0); cross(ImageDraw.Draw(cm), 255)
cg = np.zeros((S, S, 4), np.uint8)
tt = np.clip((y - (cy - 175) * F) / (380 * F), 0, 1)[..., None]
a = np.array([250, 196, 118], np.float32); b = np.array([214, 118, 52], np.float32)
cg[..., :3] = (a * (1 - tt) + b * tt).astype(np.uint8); cg[..., 3] = 255
img.paste(Image.fromarray(cg, 'RGBA'), (0, 0), cm)
# Ribbon bookmark
rb = Image.new('RGBA', (S, S), (0, 0, 0, 0)); rd = ImageDraw.Draw(rb)
rd.polygon([(int(612 * F), int(790 * F)), (int(652 * F), int(790 * F)), (int(652 * F), int(905 * F)), (int(632 * F), int(882 * F)), (int(612 * F), int(905 * F))], fill=(196, 74, 40, 255))
img = Image.alpha_composite(img, rb)
img = img.convert('RGB').resize((1024, 1024), Image.LANCZOS)
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
img.save(os.path.join(root, 'dailykjb', 'assets', 'dailykjb_app_icon.png'))
img.resize((512, 512), Image.LANCZOS).save(os.path.join(root, 'icon.png'))
