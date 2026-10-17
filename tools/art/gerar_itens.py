#!/usr/bin/env python3
"""Ícones de itens, tocha animada, rachaduras de mineração e peças da interface.

Chamado por gerar_arte.py (não precisa rodar sozinho). Lê data/generated/*.json e recusa
terminar se algum material ou item ficar sem ícone.

Gera:
    art/itens/icones.png + icones.json   um ícone 16x16 por material e item
    art/tiles/objetos.png + objetos.json objetos colocados no mundo (tocha: 3 quadros de chama)
    art/tiles/rachaduras.png             4 estágios de rachadura
    art/ui/cursor.png                    moldura do tile sob o mouse (ok e bloqueado)
    art/ui/espaco.png                    espaço do inventário (normal e selecionado)
"""

from __future__ import annotations

import json
import math
import random

from PIL import Image, ImageDraw

import gerar_arte as A

T = A.T
c = A.c
new = A.new
ROOT = A.ROOT
ART = A.ART
OUT = "1b1714"


def quantize(img: Image.Image) -> Image.Image:
    """Ícones são opacos e só usam cores da paleta: misturas viram a cor mais próxima."""
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            px[x, y] = A.nearest((r, g, b)) + (255,) if a >= 110 else (0, 0, 0, 0)
    return out


def outline(img: Image.Image, color: str = OUT) -> Image.Image:
    """Contorno de 1 px em volta da silhueta (ícones legíveis em qualquer fundo)."""
    out = new(*img.size)
    src, dst = img.load(), out.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3]:
                continue
            if any(0 <= x + dx < w and 0 <= y + dy < h and src[x + dx, y + dy][3] > 100
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                dst[x, y] = c(color)
    out.alpha_composite(img)
    return out


# ================================================================ formas genéricas


def ingot(ramp: tuple[str, str, str, str]) -> Image.Image:
    dark, mid, light, shine = ramp
    img = new()
    d = ImageDraw.Draw(img)
    d.polygon([(2, 9), (13, 9), (13, 12), (2, 12)], fill=c(mid))
    d.line([2, 12, 13, 12], fill=c(dark))
    d.line([13, 9, 13, 12], fill=c(dark))
    d.polygon([(2, 9), (4, 6), (11, 6), (13, 9)], fill=c(light))
    d.line([5, 7, 9, 7], fill=c(shine))
    d.point([10, 10], fill=c(light))
    return outline(img)


def lump(ramp: tuple[str, str, str], seed: str, count: int = 3) -> Image.Image:
    """Pedaços irregulares (carvão, coque, cascalho...)."""
    rng = random.Random(seed)
    dark, mid, light = ramp
    img = new()
    d = ImageDraw.Draw(img)
    spots = [(4, 7, 7), (8, 5, 6), (7, 9, 6)][:count]
    for x, y, r in spots:
        pts = [(x + int(r * 0.6 * math.cos(a)) + rng.randint(-1, 1), y + int(r * 0.5 * math.sin(a)) + rng.randint(-1, 1))
               for a in [i * math.tau / 7 for i in range(7)]]
        d.polygon(pts, fill=c(mid))
        d.line([x - 1, y - 1, x + 1, y - 2], fill=c(light))
        d.point([x + 1, y + 2], fill=c(dark))
    return outline(img)


def pile(ramp: tuple[str, str, str], seed: str) -> Image.Image:
    """Montinho de pó (cinzas, cal, argamassa)."""
    rng = random.Random(seed)
    dark, mid, light = ramp
    img = new()
    d = ImageDraw.Draw(img)
    d.pieslice([2, 5, 13, 17], 180, 360, fill=c(mid))
    d.line([3, 11, 12, 11], fill=c(dark))
    for _ in range(6):
        d.point([rng.randint(4, 11), rng.randint(7, 10)], fill=c(light))
    d.point([7, 6], fill=c(light))
    return outline(img)


def nuggets(ramp: tuple[str, str, str], seed: str) -> Image.Image:
    rng = random.Random(seed)
    dark, mid, light = ramp
    img = new()
    d = ImageDraw.Draw(img)
    for _ in range(4):
        x, y = rng.randint(2, 10), rng.randint(4, 11)
        w = rng.randint(3, 4)
        d.ellipse([x, y, x + w, y + w - 1], fill=c(mid))
        d.point([x + 1, y], fill=c(light))
        d.point([x + w - 1, y + w - 1], fill=c(dark))
    return outline(img)


def brick(ramp: tuple[str, str, str]) -> Image.Image:
    dark, mid, light = ramp
    img = new()
    d = ImageDraw.Draw(img)
    d.rectangle([2, 6, 13, 11], fill=c(mid))
    d.line([2, 6, 13, 6], fill=c(light))
    d.line([2, 11, 13, 11], fill=c(dark))
    d.line([13, 6, 13, 11], fill=c(dark))
    d.point([5, 8], fill=c(dark))
    d.point([10, 9], fill=c(dark))
    return outline(img)


def block_icon(tile_name: str, atlas: Image.Image, rows: list[str]) -> Image.Image:
    """O próprio bloco com os 4 lados expostos (cantos arredondados)."""
    r = rows.index(tile_name)
    x = (15 * A.VARIANTS) * T
    tile = atlas.crop((x, r * T, x + T, (r + 1) * T))
    return tile


def ore_chunk(ore: str, ores: Image.Image, host_ramp: tuple[str, str, str]) -> Image.Image:
    """Pedra com o minério à mostra."""
    dark, mid, light = host_ramp
    base = new()
    d = ImageDraw.Draw(base)
    pts = [(3, 5), (6, 2), (11, 3), (14, 7), (13, 12), (8, 14), (3, 12), (2, 8)]
    d.polygon(pts, fill=c(mid))
    d.line([3, 5, 6, 2, 11, 3], fill=c(light))
    d.line([13, 12, 8, 14, 3, 12], fill=c(dark))
    row = list(A.ORES).index(ore)
    overlay = ores.crop((0, row * T, T, (row + 1) * T))
    mask = base.split()[3]
    clipped = new()
    clipped.paste(overlay, (0, 0), mask)
    base.alpha_composite(clipped)
    return outline(base)


# ================================================================ itens específicos


def pickaxe(ramp: tuple[str, str, str]) -> Image.Image:
    dark, mid, light = ramp
    img = new()
    d = ImageDraw.Draw(img)
    for i in range(10):  # cabo na diagonal
        x, y = 3 + i, 13 - i
        d.point([x, y], fill=c("74593d"))
        d.point([x + 1, y], fill=c("57432f"))
    d.arc([2, 1, 15, 12], 200, 340, fill=c(mid), width=2)
    d.arc([2, 1, 15, 12], 215, 300, fill=c(light))
    d.point([3, 6], fill=c(dark))
    d.point([14, 6], fill=c(dark))
    d.rectangle([8, 3, 9, 5], fill=c(dark))  # encaixe
    return outline(img)


def log_icon() -> Image.Image:
    img = new()
    d = ImageDraw.Draw(img)
    d.rectangle([2, 5, 12, 11], fill=c("57432f"))
    d.line([2, 5, 12, 5], fill=c("74593d"))
    d.line([2, 11, 12, 11], fill=c("3d3128"))
    d.ellipse([10, 5, 14, 11], fill=c("b8956a"))
    d.ellipse([11, 7, 13, 9], outline=c("94744f"))
    d.line([4, 7, 8, 7], fill=c("3d3128"))
    return outline(img)


def water_drop() -> Image.Image:
    img = new()
    d = ImageDraw.Draw(img)
    d.polygon([(8, 2), (12, 8), (11, 12), (8, 13), (5, 12), (4, 8)], fill=c("4f86c0"))
    d.ellipse([4, 7, 12, 13], fill=c("4f86c0"))
    d.line([6, 8, 6, 10], fill=c("c8f0ff"))
    d.arc([4, 7, 12, 13], 20, 120, fill=c("2d4f80"))
    return outline(img)


def glass(ramp: tuple[str, str, str], glow: bool = False) -> Image.Image:
    dark, mid, light = ramp
    img = new()
    d = ImageDraw.Draw(img)
    d.rectangle([3, 3, 12, 12], fill=c(mid, 200))
    d.rectangle([3, 3, 12, 12], outline=c(dark))
    d.line([5, 10, 10, 5], fill=c(light))
    d.line([5, 7, 7, 5], fill=c(light))
    if glow:
        d.line([6, 12, 8, 9, 7, 8, 9, 4], fill=c("f7f6f0"))
    return outline(img)


def fulgurito() -> Image.Image:
    img = new()
    d = ImageDraw.Draw(img)
    pts = [(4, 13), (6, 10), (5, 7), (8, 5), (7, 3), (10, 2), (12, 5), (10, 8), (11, 11), (8, 13)]
    d.polygon(pts, fill=c("94744f"))
    d.line([6, 11, 6, 8, 8, 6, 9, 3], fill=c("7ad8ff"))
    d.point([10, 4], fill=c("c8f0ff"))
    d.line([9, 12, 10, 9], fill=c("57432f"))
    return outline(img)


def feather() -> Image.Image:
    img = new()
    d = ImageDraw.Draw(img)
    d.polygon([(4, 13), (7, 7), (11, 2), (13, 3), (11, 8), (7, 11)], fill=c("7ad8ff"))
    d.line([4, 13, 12, 3], fill=c("f7f6f0"))
    d.line([8, 9, 10, 6], fill=c("c8f0ff"))
    d.point([12, 4], fill=c("2d4f80"))
    d.line([3, 14, 4, 13], fill=c("57432f"))
    return outline(img)


def bucket() -> Image.Image:
    img = new()
    d = ImageDraw.Draw(img)
    d.polygon([(3, 6), (12, 6), (11, 13), (4, 13)], fill=c("74593d"))
    d.line([3, 6, 12, 6], fill=c("94744f"))
    d.line([4, 9, 11, 9], fill=c("4a5058"))
    d.line([4, 12, 11, 12], fill=c("4a5058"))
    d.arc([3, 1, 12, 10], 180, 360, fill=c("6b737c"))
    return outline(img)


def pan() -> Image.Image:
    img = new()
    d = ImageDraw.Draw(img)
    d.ellipse([1, 6, 14, 12], fill=c("57432f"))
    d.ellipse([3, 7, 12, 10], fill=c("74593d"))
    d.point([6, 8], fill=c("949ca3"))
    d.point([8, 9], fill=c("e2b33c"))
    d.point([10, 8], fill=c("6b737c"))
    return outline(img)


def torch_frame(frame: int, icon: bool = False) -> Image.Image:
    """Tocha: cabo de madeira, ponta enrolada e chama (3 quadros)."""
    img = new()
    d = ImageDraw.Draw(img)
    top = 7
    d.rectangle([7, top + 2, 8, 15], fill=c("74593d"))
    d.line([8, top + 2, 8, 15], fill=c("57432f"))
    d.rectangle([6, top, 9, top + 2], fill=c("3d3128"))
    d.point([6, top], fill=c("57432f"))
    flames = [
        [(7, top - 5), (9, top - 3), (10, top - 1), (5, top - 1), (6, top - 3)],
        [(8, top - 6), (10, top - 2), (9, top - 1), (5, top - 1), (6, top - 4)],
        [(6, top - 5), (9, top - 4), (10, top - 1), (6, top - 1), (5, top - 2)],
    ]
    pts = flames[frame % 3]
    d.polygon(pts, fill=c("e0503a"))
    inner = [(x + (1 if x < 8 else -1), y + 1) for x, y in pts]
    d.polygon(inner, fill=c("e2b33c"))
    d.point([7 + frame % 2, top - 2], fill=c("fbeeb0"))
    d.point([8, top - 1], fill=c("fbeeb0"))
    return outline(img) if icon else img


def campfire() -> Image.Image:
    img = new()
    d = ImageDraw.Draw(img)
    d.line([2, 13, 13, 10], fill=c("57432f"), width=2)
    d.line([2, 10, 13, 13], fill=c("74593d"), width=2)
    d.polygon([(8, 2), (11, 8), (10, 11), (5, 11), (5, 7)], fill=c("e0503a"))
    d.polygon([(8, 5), (10, 9), (6, 10), (6, 8)], fill=c("e2b33c"))
    d.point([8, 8], fill=c("fbeeb0"))
    return outline(img)


def workbench() -> Image.Image:
    img = new()
    d = ImageDraw.Draw(img)
    d.rectangle([1, 6, 14, 8], fill=c("94744f"))
    d.line([1, 6, 14, 6], fill=c("b8956a"))
    d.rectangle([2, 9, 3, 14], fill=c("57432f"))
    d.rectangle([12, 9, 13, 14], fill=c("57432f"))
    d.line([3, 11, 12, 11], fill=c("74593d"))
    d.rectangle([9, 3, 11, 5], fill=c("6b737c"))  # martelo em cima
    d.line([7, 5, 9, 4], fill=c("74593d"))
    return outline(img)


def furnace(body: tuple[str, str, str], glow: str) -> Image.Image:
    dark, mid, light = body
    img = new()
    d = ImageDraw.Draw(img)
    d.pieslice([2, 2, 13, 20], 180, 360, fill=c(mid))
    d.rectangle([2, 11, 13, 14], fill=c(mid))
    d.arc([2, 2, 13, 20], 200, 260, fill=c(light))
    d.line([2, 14, 13, 14], fill=c(dark))
    d.rectangle([6, 9, 9, 13], fill=c("1b1714"))
    d.rectangle([7, 11, 8, 13], fill=c(glow))
    d.point([7, 10], fill=c("fbeeb0"))
    d.rectangle([10, 1, 11, 4], fill=c(dark))  # chaminé
    return outline(img)


def brick_oven(ramp: tuple[str, str, str], glow: str) -> Image.Image:
    dark, mid, light = ramp
    img = new()
    d = ImageDraw.Draw(img)
    d.rectangle([2, 4, 13, 14], fill=c(mid))
    for y in (6, 9, 12):
        d.line([2, y, 13, y], fill=c(dark))
    for y, off in ((5, 0), (8, 3), (11, 0)):
        for x in range(2 + off, 14, 6):
            d.point([x, y], fill=c(dark))
    d.line([2, 4, 13, 4], fill=c(light))
    d.rectangle([5, 9, 10, 14], fill=c("1b1714"))
    d.rectangle([6, 11, 9, 14], fill=c(glow))
    d.point([7, 12], fill=c("fbeeb0"))
    return outline(img)


def bolt() -> Image.Image:
    img = new()
    d = ImageDraw.Draw(img)
    d.polygon([(9, 1), (4, 9), (8, 9), (6, 15), (12, 6), (8, 6), (11, 1)], fill=c("7ad8ff"))
    d.line([9, 2, 6, 8], fill=c("c8f0ff"))
    d.line([8, 9, 7, 13], fill=c("f7f6f0"))
    return outline(img)


def hand() -> Image.Image:
    img = new()
    d = ImageDraw.Draw(img)
    d.rectangle([5, 6, 10, 12], fill=c("b8956a"))
    for x in (5, 7, 9):
        d.rectangle([x, 3, x + 1, 6], fill=c("b8956a"))
    d.rectangle([11, 7, 12, 9], fill=c("b8956a"))
    d.line([5, 12, 10, 12], fill=c("94744f"))
    return outline(img)


# ================================================================ estações no mundo


def campfire_world(frame: int) -> Image.Image:
    img = new()
    d = ImageDraw.Draw(img)
    for x, tone in ((1, "6b737c"), (4, "949ca3"), (10, "949ca3"), (13, "6b737c")):  # pedras em volta
        d.ellipse([x, 12, x + 2, 14], fill=c(tone))
    d.line([3, 14, 12, 11], fill=c("57432f"), width=2)
    d.line([3, 11, 12, 14], fill=c("74593d"), width=2)
    shapes = [
        [(8, 2), (11, 8), (10, 11), (5, 11), (5, 6)],
        [(7, 1), (11, 7), (10, 11), (5, 11), (4, 7)],
        [(9, 3), (12, 8), (10, 11), (5, 11), (6, 5)],
    ]
    pts = shapes[frame % 3]
    d.polygon(pts, fill=c("e0503a"))
    d.polygon([(x + (1 if x < 8 else -1), y + 2) for x, y in pts], fill=c("e2b33c"))
    d.point([7 + frame % 2, 8], fill=c("fbeeb0"))
    d.point([8, 9], fill=c("fbeeb0"))
    if frame == 1:
        d.point([10, 0], fill=c("f28a5c"))  # fagulha
    return outline(img)


def oven_world(icon_painter, frame: int, glow_a: str, glow_b: str) -> Image.Image:
    """Estação com brilho que pisca na boca do forno."""
    img = icon_painter()
    px = img.load()
    for y in range(T):
        for x in range(T):
            r, g, b, a = px[x, y]
            if a and (r, g, b) == A.PAL[glow_a]:
                px[x, y] = c(glow_b if frame % 2 else glow_a)
    return img


# ================================================================ movimento (Onda 5)

WOOD = ("3d3128", "57432f", "74593d", "94744f", "b8956a")


def door_half(top: bool, open_: bool) -> Image.Image:
    """Porta de tábuas verticais com travessas; aberta mostra só a borda presa à dobradiça."""
    img = new()
    d = ImageDraw.Draw(img)
    dark, deep, mid, light, pale = WOOD
    if open_:
        d.rectangle([2, 0, 4, 15], fill=c(mid))
        d.line([2, 0, 2, 15], fill=c(light))
        d.line([4, 0, 4, 15], fill=c(deep))
        d.point([3, 3 if top else 12], fill=c("6b737c"))
        if top:
            d.line([2, 0, 4, 0], fill=c(dark))
        return img
    d.rectangle([3, 0, 12, 15], fill=c(mid))
    for x in (5, 8, 11):
        d.line([x, 0, x, 15], fill=c(deep))
    d.line([3, 0, 3, 15], fill=c(light))
    d.line([12, 0, 12, 15], fill=c(dark))
    if top:
        d.line([3, 0, 12, 0], fill=c(pale))
        d.rectangle([3, 4, 12, 5], fill=c(light))
        d.line([3, 5, 12, 5], fill=c(deep))
        d.rectangle([6, 8, 9, 11], fill=c(dark))  # postigo
        d.point([7, 9], fill=c("4f86c0"))
    else:
        d.rectangle([3, 9, 12, 10], fill=c(light))
        d.line([3, 10, 12, 10], fill=c(deep))
        d.line([3, 15, 12, 15], fill=c(dark))
        d.rectangle([10, 3, 11, 4], fill=c("b8801a"))  # maçaneta
        d.point([10, 3], fill=c("f2d36b"))
    return img


def platform_tile() -> Image.Image:
    img = new()
    d = ImageDraw.Draw(img)
    dark, deep, mid, light, pale = WOOD
    d.rectangle([0, 0, 15, 3], fill=c(mid))
    d.line([0, 0, 15, 0], fill=c(pale))
    d.line([0, 3, 15, 3], fill=c(dark))
    d.line([7, 1, 7, 2], fill=c(deep))
    d.point([3, 1], fill=c(light))
    d.point([12, 2], fill=c(deep))
    d.line([2, 4, 4, 6], fill=c(deep))  # mão-francesa
    d.line([13, 4, 11, 6], fill=c(deep))
    return img


def ladder_tile() -> Image.Image:
    img = new()
    d = ImageDraw.Draw(img)
    dark, deep, mid, light, pale = WOOD
    for x in (3, 11):
        d.rectangle([x, 0, x + 1, 15], fill=c(mid))
        d.line([x, 0, x, 15], fill=c(light))
    for y in (2, 7, 12):
        d.rectangle([5, y, 10, y + 1], fill=c(light))
        d.line([5, y + 1, 10, y + 1], fill=c(deep))
    return img


def rope_tile() -> Image.Image:
    img = new()
    px = img.load()
    for y in range(16):
        left = (y // 2) % 2 == 0
        px[7, y] = c("b8956a" if left else "94744f")
        px[8, y] = c("94744f" if left else "74593d")
        if y % 4 == 0:
            px[7, y] = c("fbeeb0")
    return img


def door_icon() -> Image.Image:
    top, bottom = door_half(True, False), door_half(False, False)
    img = new()
    img.alpha_composite(top.resize((16, 8), Image.NEAREST), (0, 0))
    img.alpha_composite(bottom.resize((16, 8), Image.NEAREST), (0, 8))
    return outline(img)


def platform_icon() -> Image.Image:
    img = new()
    img.alpha_composite(platform_tile(), (0, 5))
    return outline(img)


def rope_icon() -> Image.Image:
    img = new()
    d = ImageDraw.Draw(img)
    for r, col in ((6, "74593d"), (5, "b8956a"), (3, "94744f")):
        d.ellipse([8 - r, 8 - r, 7 + r, 7 + r], outline=c(col))
    d.line([12, 10, 14, 15], fill=c("94744f"))
    d.point([9, 3], fill=c("fbeeb0"))
    return outline(img)


def fiber_icon() -> Image.Image:
    img = new()
    d = ImageDraw.Draw(img)
    for i, col in enumerate(("2f5a3a", "4f8a4a", "86b85a", "4f8a4a")):
        d.line([4 + i * 2, 14, 6 + i, 2 + i], fill=c(col))
    d.line([3, 9, 12, 8], fill=c("b8956a"))  # amarrado
    return outline(img)


MOVEMENT_FRAMES = {
    "porta": ([door_half(False, False), door_half(False, True)], 0),
    "porta_alto": ([door_half(True, False), door_half(True, True)], 0),
    "plataforma": ([platform_tile()], 1),
    "escada": ([ladder_tile()], 1),
    "corda": ([rope_tile()], 1),
}


STATION_FRAMES = {
    "fogueira": ([campfire_world(f) for f in range(3)], 8),
    "bancada": ([workbench()], 1),
    "fornalha": ([oven_world(lambda: furnace(("57432f", "94744f", "b8956a"), "e0503a"), f, "e0503a", "f28a5c")
                  for f in range(2)], 3),
    "forno": ([oven_world(lambda: brick_oven(("5e161a", "8a2224", "b8322a"), "e2b33c"), f, "e2b33c", "f2d36b")
               for f in range(2)], 3),
    "forno_de_vidro": ([oven_world(lambda: brick_oven(("94744f", "e2b33c", "fbeeb0"), "7ad8ff"), f, "7ad8ff", "c8f0ff")
                        for f in range(2)], 3),
}


# ================================================================ mapa id -> ícone

METALS = {
    "lingote_cobre": ("8a2224", "e0503a", "f28a5c", "fbeeb0"),
    "lingote_estanho": ("6b737c", "bfc5c9", "e3e6e4", "f7f6f0"),
    "bronze": ("5c3d12", "b8801a", "e2b33c", "fbeeb0"),
    "lingote_ferro": ("2b231d", "4a5058", "6b737c", "949ca3"),
    "aco": ("4a5058", "949ca3", "bfc5c9", "c8f0ff"),
    "lingote_prata": ("6b737c", "e3e6e4", "f7f6f0", "c8f0ff"),
    "lingote_ouro": ("8a5a12", "e2b33c", "f2d36b", "fbeeb0"),
    "electro": ("8a5a12", "f2d36b", "e3e6e4", "f7f6f0"),
}
PICK_HEADS = {
    "picareta_silex": ("1b1714", "2b231d", "949ca3"),
    "picareta_cobre": ("8a2224", "e0503a", "f28a5c"),
    "picareta_bronze": ("5c3d12", "b8801a", "e2b33c"),
    "picareta_ferro": ("2b231d", "4a5058", "949ca3"),
    "picareta_aco": ("4a5058", "bfc5c9", "f7f6f0"),
}
ORE_HOSTS = {
    "malaquita": ("4a5058", "949ca3", "bfc5c9"),
    "carvao_mineral": ("4a5058", "949ca3", "bfc5c9"),
    "limonita": ("3d3128", "74593d", "94744f"),
    "hematita": ("2b231d", "6b737c", "949ca3"),
    "quartzo": ("2b231d", "6b737c", "949ca3"),
    "acantita": ("2b231d", "6b737c", "949ca3"),
    "silex": ("57432f", "94744f", "b8956a"),
}
BLOCKS = ["terra", "argila", "areia", "cascalho", "calcario", "xisto"]


def icon_for(item_id: str, tiles: dict) -> Image.Image | None:
    if item_id in BLOCKS:
        return block_icon(item_id, tiles["atlas"], tiles["rows"])
    if item_id in ORE_HOSTS:
        return ore_chunk(item_id, tiles["ores"], ORE_HOSTS[item_id])
    if item_id in METALS:
        return ingot(METALS[item_id])
    if item_id in PICK_HEADS:
        return pickaxe(PICK_HEADS[item_id])
    table = {
        "madeira": log_icon,
        "agua": water_drop,
        "carvao_vegetal": lambda: lump(("0f0d0c", "1b1714", "4a5058"), "carvao_vegetal"),
        "coque": lambda: lump(("1b1714", "4a5058", "949ca3"), "coque"),
        "cinzas": lambda: pile(("4a5058", "949ca3", "bfc5c9"), "cinzas"),
        "cal_virgem": lambda: pile(("949ca3", "e3e6e4", "f7f6f0"), "cal"),
        "argamassa": lambda: pile(("6b737c", "bfc5c9", "e3e6e4"), "argamassa"),
        "cassiterita": lambda: nuggets(("0f0d0c", "2b231d", "94744f"), "cassiterita"),
        "ouro_aluvial": lambda: nuggets(("8a5a12", "e2b33c", "fbeeb0"), "ouro"),
        "tijolo": lambda: brick(("5e161a", "8a2224", "b8322a")),
        "tijolo_refratario": lambda: brick(("94744f", "e2b33c", "fbeeb0")),
        "vidro": lambda: glass(("4f86c0", "c8f0ff", "f7f6f0")),
        "vidro_de_tempestade": lambda: glass(("2d4f80", "7ad8ff", "c8f0ff"), glow=True),
        "fulgurito": fulgurito,
        "pena_ave_trovao": feather,
        "tocha": lambda: torch_frame(0, icon=True),
        "porta": door_icon,
        "plataforma": platform_icon,
        "escada": lambda: outline(ladder_tile()),
        "corda": rope_icon,
        "fibra": fiber_icon,
        "fogueira": campfire,
        "bancada": workbench,
        "fornalha": lambda: furnace(("57432f", "94744f", "b8956a"), "e0503a"),
        "forno": lambda: brick_oven(("5e161a", "8a2224", "b8322a"), "e2b33c"),
        "forno_de_vidro": lambda: brick_oven(("94744f", "e2b33c", "fbeeb0"), "7ad8ff"),
        "bateia": pan,
        "balde": bucket,
        "raio": bolt,
        "mao": hand,
    }
    painter = table.get(item_id)
    return painter() if painter else None


# ================================================================ montagem


def build(tiles: dict) -> dict:
    gen = ROOT / "data" / "generated"
    ids = [m["id"] for m in json.loads((gen / "materiais.json").read_text(encoding="utf-8"))["materiais"]]
    ids += [i["id"] for i in json.loads((gen / "itens.json").read_text(encoding="utf-8"))["itens"]]
    missing = [i for i in ids if icon_for(i, tiles) is None]
    if missing:
        raise SystemExit(f"itens sem ícone: {', '.join(missing)} (desenhe em tools/art/gerar_itens.py)")

    cols = 16
    rows = math.ceil(len(ids) / cols)
    sheet = new(cols * T, rows * T)
    mapping = {}
    for index, item_id in enumerate(ids):
        sheet.alpha_composite(quantize(icon_for(item_id, tiles)), ((index % cols) * T, (index // cols) * T))
        mapping[item_id] = index
    (ART / "itens").mkdir(parents=True, exist_ok=True)
    sheet.save(ART / "itens" / "icones.png")
    (ART / "itens" / "icones.json").write_text(
        json.dumps({"tamanho": T, "colunas": cols, "icones": mapping}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8")

    # Objetos no mundo: uma linha por objeto, colunas = quadros de animação.
    world_objects = {"tocha": ([torch_frame(f) for f in range(3)], 8)}
    world_objects.update(STATION_FRAMES)
    world_objects.update(MOVEMENT_FRAMES)
    objects = new(3 * T, T * len(world_objects))
    meta = {}
    for row, (name, (frames, fps)) in enumerate(world_objects.items()):
        for col, frame in enumerate(frames):
            objects.alpha_composite(quantize(frame), (col * T, row * T))
        meta[name] = {"linha": row, "quadros": len(frames), "fps": fps}
        if fps == 0:
            meta[name]["estatico"] = True  # quadro escolhido pelo jogo (porta aberta/fechada)
    objects.save(ART / "tiles" / "objetos.png")
    (ART / "tiles" / "objetos.json").write_text(json.dumps(
        {"objetos": meta}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    # Rachaduras: 4 estágios, cada um somando rachaduras ao anterior.
    cracks = new(4 * T, T)
    rng = random.Random("rachaduras")
    paths: list[list[tuple[int, int]]] = []
    for stage in range(4):
        for _ in range(2):
            x, y = rng.randint(4, 11), rng.randint(4, 11)
            path = [(x, y)]
            for _ in range(rng.randint(3, 6)):
                x = max(0, min(T - 1, x + rng.choice((-1, 0, 1))))
                y = max(0, min(T - 1, y + rng.choice((-1, 1))))
                path.append((x, y))
            paths.append(path)
        tile = new()
        d = ImageDraw.Draw(tile)
        for path in paths:
            d.line(path, fill=c("0f0d0c", 210))
            for px_, py_ in path[1::2]:
                if px_ + 1 < T:
                    d.point([px_ + 1, py_], fill=c("f7f6f0", 70))
        cracks.alpha_composite(tile, (stage * T, 0))
    cracks.save(ART / "tiles" / "rachaduras.png")

    # Cursor: cantos em L, branco (pode) e vermelho (não pode).
    (ART / "ui").mkdir(parents=True, exist_ok=True)
    cursor = new(2 * (T + 2), T + 2)
    for i, color in enumerate(("f7f6f0", "e0503a")):
        d = ImageDraw.Draw(cursor)
        ox = i * (T + 2)
        s = T + 1
        for (x0, y0, dx, dy) in ((0, 0, 1, 1), (s, 0, -1, 1), (0, s, 1, -1), (s, s, -1, -1)):
            d.line([ox + x0, y0, ox + x0 + 4 * dx, y0], fill=c(color))
            d.line([ox + x0, y0, ox + x0, y0 + 4 * dy], fill=c(color))
    cursor.save(ART / "ui" / "cursor.png")

    # Espaço do inventário 20x20: normal e selecionado.
    slot = new(40, 20)
    d = ImageDraw.Draw(slot)
    d.rectangle([0, 0, 19, 19], fill=c("1b1714", 200), outline=c("57432f"))
    d.line([1, 1, 18, 1], fill=c("3d3128"))
    d.rectangle([20, 0, 39, 19], fill=c("3d3128", 220), outline=c("e2b33c"))
    d.rectangle([21, 1, 38, 18], outline=c("b8801a"))
    slot.save(ART / "ui" / "espaco.png")
    return {"icons": sheet, "objects": objects, "cracks": cracks, "cursor": cursor, "slot": slot, "count": len(ids)}
