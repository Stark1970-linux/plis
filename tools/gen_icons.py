#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2026 команда S.T.A.R.K.
"""Рисует значок приложения (резистор на тёмной сетке) в нужных размерах.

Запуск:  python3 tools/gen_icons.py      (нужна библиотека Pillow)
Готовые PNG уже лежат в android/res/, этот скрипт нужен только если значок решат менять.
"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "android", "res")
SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}

BG, GRID, INK = (20, 35, 58), (34, 54, 84), (63, 193, 232)


def draw(size):
    k = 8                      # рисуем в 8 раз крупнее и уменьшаем: края получаются гладкими
    s = size * k
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * 0.22), fill=BG)
    step = s / 8
    for i in range(1, 8):      # сетка, как на холсте редактора
        d.line([(i * step, 0), (i * step, s)], fill=GRID, width=max(1, s // 200))
        d.line([(0, i * step), (s, i * step)], fill=GRID, width=max(1, s // 200))
    w = int(s * 0.045)
    y = s // 2
    x0, x1 = int(s * 0.13), int(s * 0.87)
    bx0, bx1 = int(s * 0.31), int(s * 0.69)
    by0, by1 = int(s * 0.40), int(s * 0.60)
    d.line([(x0, y), (bx0, y)], fill=INK, width=w)
    d.line([(bx1, y), (x1, y)], fill=INK, width=w)
    d.rectangle([bx0, by0, bx1, by1], outline=INK, width=w)
    r = int(s * 0.04)
    for x in (x0, x1):         # узлы на концах выводов
        d.ellipse([x - r, y - r, x + r, y + r], fill=INK)
    # маска скруглённых углов, чтобы сетка не торчала за край
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * 0.22), fill=255)
    img.putalpha(mask)
    return img.resize((size, size), Image.LANCZOS)


for name, px in SIZES.items():
    folder = os.path.join(ROOT, "mipmap-" + name)
    os.makedirs(folder, exist_ok=True)
    draw(px).save(os.path.join(folder, "ic_launcher.png"))
    print("готово:", name, px)
