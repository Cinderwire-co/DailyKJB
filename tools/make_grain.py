#!/usr/bin/env python3
"""Draws the paper grain the app lays over its pages: a seamless tile, only an
alpha mask, which the app tints for light or dark.

  tools/.venv/bin/python tools/make_grain.py
"""
import os
import numpy as np, sys
from PIL import Image
rng = np.random.default_rng(1611)
N = 384
def blur(a, s):
    # Gaussian blur by FFT: wraps around, so the tile is seamless
    f = np.fft.fftfreq(N)
    fx, fy = np.meshgrid(f, f)
    g = np.exp(-2 * (np.pi ** 2) * (s ** 2) * (fx ** 2 + fy ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))
fine = blur(rng.standard_normal((N, N)), 0.6)
mid = blur(rng.standard_normal((N, N)), 3.0)
broad = blur(rng.standard_normal((N, N)), 22.0)
# Fibres: short streaks
fib = np.zeros((N, N))
for _ in range(260):
    x, y = rng.integers(0, N, 2); L = rng.integers(6, 22); ang = rng.uniform(0, np.pi)
    for t in range(L):
        fib[int(y + t * np.sin(ang)) % N, int(x + t * np.cos(ang)) % N] += 1
fib = blur(fib, 0.5)
def norm(a): return (a - a.mean()) / (a.std() + 1e-9)
v = 0.55 * norm(fine) + 0.35 * norm(mid) + 0.55 * norm(broad) + 0.35 * norm(fib)
v = norm(v)
alpha = np.clip((v + 0.4) * 22, 0, 70).astype(np.uint8)
img = np.zeros((N, N, 4), np.uint8); img[..., 3] = alpha
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
Image.fromarray(img, 'RGBA').save(os.path.join(root, 'dailykjb', 'assets', 'images', 'paper_grain.png'), optimize=True)
