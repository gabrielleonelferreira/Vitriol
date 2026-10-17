#!/usr/bin/env python3
"""Gera a arte do jogo (tiles, fundo e personagem) só com as cores da paleta oficial.

Uso (na raiz do repositório):
    pip install pillow
    python3 tools/art/gerar_arte.py

Gera em art/:
    tiles/tiles.png      blocos: uma linha por tile; coluna = máscara * 4 + variação
    tiles/minerios.png   minérios por cima da rocha, no mesmo esquema de colunas
    tiles/paredes.png    paredes de fundo: uma linha por material, 4 variações
    tiles/sombras.png    16 sombras para as paredes, conforme os blocos vizinhos
    tiles/tiles.json     mapa nome -> linha, e como ler as colunas
    fundo/*.png          céu, montanhas, colinas e nuvens (paralaxe)
    personagem/*.png     folhas de animação 16x32 por parte do corpo
    personagem/personagem.json
e a prancha docs/img/arte-base.png.

Máscara (4 bits) = lados do tile expostos: 1 topo, 2 direita, 4 baixo, 8 esquerda. Com ela cada
bloco ganha contorno, brilho, sombra e cantos arredondados só onde está exposto.
A arte é determinística: rodar de novo gera os mesmos arquivos.
"""

from __future__ import annotations

import json
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "art"
T = 16
VARIANTS = 4
MASKS = 16
TOP, RIGHT, BOTTOM, LEFT = 1, 2, 4, 8

PALETTE = [line.strip() for line in (ART / "paleta" / "vitriol.hex").read_text().split() if line.strip()]
PAL = {h: tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) for h in PALETTE}
CLEAR = (0, 0, 0, 0)


def c(hexcode: str, alpha: int = 255) -> tuple[int, int, int, int]:
    if hexcode not in PAL:
        raise ValueError(f"cor fora da paleta: {hexcode}")
    return PAL[hexcode] + (alpha,)


def new(w: int = T, h: int = T) -> Image.Image:
    return Image.new("RGBA", (w, h), CLEAR)


def nearest(rgb: tuple[int, int, int]) -> tuple[int, int, int]:
    return min(PAL.values(), key=lambda p: sum((p[i] - rgb[i]) ** 2 for i in range(3)))


# ================================================================ texturas de base


def clustered(rng: random.Random, ramp: list[str], weights: list[float], passes: int = 4) -> Image.Image:
    """Manchas suaves: sorteia tons e deixa vizinhos copiarem uns aos outros."""
    img = new()
    px = img.load()
    for y in range(T):
        for x in range(T):
            px[x, y] = c(rng.choices(ramp, weights)[0])
    for _ in range(passes):
        for y in range(T):
            for x in range(T):
                if rng.random() < 0.5:
                    px[x, y] = px[(x + rng.choice((-1, 0, 1))) % T, (y + rng.choice((-1, 0, 1))) % T]
    return img


def stone(d, x, y, w, h, dark, mid, light, rim=None) -> None:
    """Pedra com luz de cima-esquerda: brilho em cima, sombra embaixo-direita."""
    d.ellipse([x, y, x + w - 1, y + h - 1], fill=c(mid))
    if w >= 3 and h >= 3:
        d.line([x + 1, y + h - 1, x + w - 2, y + h - 1], fill=c(dark))
        d.line([x + w - 1, y + 1, x + w - 1, y + h - 2], fill=c(dark))
        d.point([x + 1, y + 1], fill=c(light))
        if w >= 4:
            d.point([x + 2, y + 1], fill=c(light))
    if rim:
        d.line([x + 1, y + h, x + w - 1, y + h], fill=c(rim, 160))


def terra(rng):
    img = clustered(rng, ["57432f", "74593d", "94744f"], [2.2, 8, 1.0], 5)
    d = ImageDraw.Draw(img)
    for _ in range(rng.randint(2, 3)):
        stone(d, rng.randrange(0, 13), rng.randrange(0, 13), rng.choice((2, 3, 3, 4)), rng.choice((2, 3)),
              "3d3128", "94744f", "b8956a")
    if rng.random() < 0.5:  # raiz fina
        x, y = rng.randrange(0, 14), rng.randrange(0, 6)
        for _ in range(rng.randint(4, 7)):
            d.point([x, y], fill=c("3d3128"))
            x, y = x + rng.choice((-1, 0, 1)), y + 1
    for _ in range(3):
        d.point([rng.randrange(T), rng.randrange(T)], fill=c("3d3128"))
    return img


def argila(rng):
    img = clustered(rng, ["94744f", "b8956a", "b8801a"], [3, 6, 0.6], 5)
    d = ImageDraw.Draw(img)
    for y in (3 + rng.randrange(2), 8 + rng.randrange(2), 13 + rng.randrange(2)):
        x0 = rng.randrange(-3, 3)
        d.line([x0, y, x0 + rng.randrange(7, 14), y], fill=c("74593d"))
        d.line([x0 + 1, y - 1, x0 + rng.randrange(4, 9), y - 1], fill=c("e2b33c"))
    return img


def areia(rng):
    img = clustered(rng, ["94744f", "b8956a", "f2d36b"], [1, 7, 2.2], 3)
    px = img.load()
    for _ in range(10):
        px[rng.randrange(T), rng.randrange(T)] = c(rng.choice(("fbeeb0", "74593d")))
    d = ImageDraw.Draw(img)
    for y in (5 + rng.randrange(3), 11 + rng.randrange(3)):  # marcas de vento
        x = rng.randrange(0, 6)
        d.line([x, y, x + 3, y - 1, x + 6, y], fill=c("94744f"))
    return img


def cascalho(rng):
    img = clustered(rng, ["3d3128", "57432f"], [1, 2], 2)
    d = ImageDraw.Draw(img)
    spots = [(rng.randrange(-1, 14), rng.randrange(-1, 14)) for _ in range(11)]
    for x, y in sorted(spots, key=lambda s: s[1]):
        w = rng.choice((3, 4, 4, 5))
        tone = rng.choice((("4a5058", "6b737c", "bfc5c9"), ("4a5058", "949ca3", "e3e6e4"),
                           ("57432f", "94744f", "b8956a")))
        stone(d, x, y, w, rng.choice((3, 3, 4)), *tone, rim="1b1714")
    return img


def calcario(rng):
    img = clustered(rng, ["6b737c", "949ca3", "bfc5c9"], [2, 6, 1.1], 4)
    d = ImageDraw.Draw(img)
    for y in (4 + rng.randrange(3), 11 + rng.randrange(3)):
        x0 = rng.randrange(-4, 2)
        d.line([x0, y, x0 + rng.randrange(9, 18), y], fill=c("6b737c"))
    if rng.random() < 0.2:  # concha fóssil, rara (o calcário vem de conchas e corais)
        x, y = rng.randrange(2, 10), rng.randrange(1, 10)
        d.arc([x, y, x + 5, y + 4], 180, 360, fill=c("4a5058"))
        d.line([x + 2, y + 1, x + 2, y + 2], fill=c("4a5058"))
        d.line([x + 3, y + 1, x + 3, y + 2], fill=c("e3e6e4"))
    return img


def xisto(rng):
    img = clustered(rng, ["4a5058", "6b737c", "949ca3"], [3, 6, 2], 3)
    d = ImageDraw.Draw(img)
    for k in range(-T, T, 4):
        o = k + rng.randrange(2)
        d.line([0, o + 6, T - 1, o], fill=c("4a5058"))
    for _ in range(4):  # mica brilhando
        d.point([rng.randrange(T), rng.randrange(T)], fill=c("e3e6e4"))
    if rng.random() < 0.08:  # granada (rara)
        x, y = rng.randrange(2, 13), rng.randrange(2, 13)
        d.rectangle([x, y, x + 1, y + 1], fill=c("8a2224"))
        d.point([x, y], fill=c("e0503a"))
    return img


def rocha_base(rng):
    img = clustered(rng, ["0f0d0c", "1b1714", "2b231d"], [3, 5, 2], 3)
    d = ImageDraw.Draw(img)
    for _ in range(2):
        x, y = rng.randrange(T), 0
        while y < T:
            nx = max(0, min(T - 1, x + rng.choice((-1, 0, 1))))
            d.line([x, y, nx, y + 2], fill=c("3d3128"))
            x, y = nx, y + 2
    d.point([rng.randrange(T), rng.randrange(T)], fill=c("57432f"))
    return img


# ================================================================ blocos construídos


def tijolo(rng, ramp=("5e161a", "8a2224", "b8322a"), mortar="bfc5c9"):
    """Tijolos em amarração (fiadas desencontradas) com argamassa clara."""
    dark, mid, light = ramp
    img = new()
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, T - 1, T - 1], fill=c(mortar))
    for row in range(4):
        y0 = row * 4
        offset = 0 if row % 2 == 0 else 4
        for x0 in range(-8 + offset, T, 8):
            x1 = x0 + 6
            if x1 < 0:
                continue
            d.rectangle([max(0, x0), y0, min(T - 1, x1), y0 + 2], fill=c(mid))
            d.line([max(0, x0), y0, min(T - 1, x1), y0], fill=c(light))
            d.line([max(0, x0), y0 + 2, min(T - 1, x1), y0 + 2], fill=c(dark))
            if rng.random() < 0.3:
                d.point([rng.randint(max(0, x0), max(0, min(T - 1, x1))), y0 + 1], fill=c(dark))
    return img


def tijolo_refratario(rng):
    return tijolo(rng, ("94744f", "e2b33c", "fbeeb0"), "74593d")


def argamassa(rng):
    img = clustered(rng, ["949ca3", "bfc5c9", "e3e6e4"], [2, 6, 1.5], 4)
    d = ImageDraw.Draw(img)
    for _ in range(5):
        d.point([rng.randrange(T), rng.randrange(T)], fill=c("6b737c"))
    for _ in range(2):  # marcas de colher de pedreiro
        x, y = rng.randrange(0, 10), rng.randrange(2, 14)
        d.arc([x, y, x + 6, y + 3], 200, 340, fill=c("949ca3"))
    return img


def vidro(rng, tint=("4f86c0", "9fd3f0", "f7f6f0"), storm=False):
    """Vidro: quase transparente, com reflexos diagonais. A moldura vem das bordas (máscara)."""
    dark, mid, light = tint
    img = new()
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, T - 1, T - 1], fill=c(mid, 60))
    off = rng.randint(0, 4)
    d.line([2 + off, 12, 9 + off, 5], fill=c(light, 200))
    d.line([4 + off, 13, 11 + off, 6], fill=c(light, 110))
    d.point([12, 3], fill=c(light, 230))
    if storm:  # vidro de tempestade: um raio preso no vidro
        d.line([7, 1, 5, 6, 8, 8, 6, 14], fill=c("7ad8ff", 230))
        d.point([5, 6], fill=c("c8f0ff"))
    return img


def vidro_de_tempestade(rng):
    return vidro(rng, ("2d4f80", "7ad8ff", "c8f0ff"), storm=True)


def fulgurito(rng):
    """Areia fundida pelo raio: tubos de vidro escuro e ramificados, com brilho azul por dentro."""
    img = areia(rng)
    d = ImageDraw.Draw(img)
    x = 6 + rng.randrange(4)
    pts = [(x, 0)]
    y = 0
    while y < T - 1:
        y = min(T - 1, y + rng.randrange(2, 5))
        x = max(2, min(T - 3, x + rng.choice((-2, -1, 1, 2))))
        pts.append((x, y))
    d.line(pts, fill=c("2b231d"), width=3)
    d.line(pts, fill=c("4a5058"), width=1)
    for px_, py_ in pts[1:-1:2]:  # ramos
        side = rng.choice((-1, 1))
        d.line([px_, py_, px_ + side * 3, py_ + 2], fill=c("3d3128"))
    for px_, py_ in pts[::2]:
        d.point([px_, py_], fill=c("7ad8ff"))
    return img


# ================================================================ máscara e bordas


def corner_cuts(mask: int) -> set[tuple[int, int]]:
    """Pixels removidos para arredondar cantos onde dois lados vizinhos estão expostos."""
    cuts: set[tuple[int, int]] = set()
    shape = [(0, 0), (1, 0), (0, 1)]
    if mask & TOP and mask & LEFT:
        cuts |= set(shape)
    if mask & TOP and mask & RIGHT:
        cuts |= {(T - 1 - x, y) for x, y in shape}
    if mask & BOTTOM and mask & LEFT:
        cuts |= {(x, T - 1 - y) for x, y in shape}
    if mask & BOTTOM and mask & RIGHT:
        cuts |= {(T - 1 - x, T - 1 - y) for x, y in shape}
    return cuts


def is_out(inside, mask: int, x: int, y: int) -> bool:
    if 0 <= x < T and 0 <= y < T:
        return not inside[y][x]
    if y < 0:
        return bool(mask & TOP)
    if y >= T:
        return bool(mask & BOTTOM)
    if x < 0:
        return bool(mask & LEFT)
    return bool(mask & RIGHT)


def apply_edges(base: Image.Image, mask: int, outline: str, light: str, shade: str) -> Image.Image:
    """Recorta os cantos e pinta contorno, brilho (topo/esquerda) e sombra (baixo/direita)."""
    img = base.copy()
    px = img.load()
    cuts = corner_cuts(mask)
    inside = [[(x, y) not in cuts for x in range(T)] for y in range(T)]
    edge = [[False] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            if not inside[y][x]:
                px[x, y] = CLEAR
            elif any(is_out(inside, mask, x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                edge[y][x] = True
                px[x, y] = c(outline)
    for y in range(T):
        for x in range(T):
            if not inside[y][x] or edge[y][x]:
                continue
            up = y > 0 and edge[y - 1][x] and is_out(inside, mask, x, y - 2)
            left = x > 0 and edge[y][x - 1] and is_out(inside, mask, x - 2, y)
            down = y < T - 1 and edge[y + 1][x] and is_out(inside, mask, x, y + 2)
            right = x < T - 1 and edge[y][x + 1] and is_out(inside, mask, x + 2, y)
            if up or (left and (x + y) % 2 == 0):
                px[x, y] = c(light)
            elif down or (right and (x + y) % 2 == 0):
                px[x, y] = c(shade)
    return img


GREENS = ["1f3a2a", "2f5a3a", "4f8a4a", "86b85a"]


def grass_edges(base: Image.Image, mask: int, rng: random.Random) -> Image.Image:
    """Terra com grama: folhas no topo exposto, escorrendo pelos lados expostos."""
    img = apply_edges(base, mask, "3d3128", "94744f", "57432f")
    if not mask & TOP:
        return img
    px = img.load()
    for x in range(T):
        depth = 3 + rng.choice((0, 0, 1, 1, 2))
        if (mask & LEFT and x < 2) or (mask & RIGHT and x > T - 3):
            depth += rng.randint(3, 6)
        for y in range(depth + 1):
            if px[x, y][3] == 0:
                continue
            px[x, y] = c(GREENS[0] if y == depth else GREENS[1] if y == depth - 1 else GREENS[2])
        # Topo: lâminas de grama; colunas mais baixas formam a silhueta.
        if px[x, 0][3]:
            if rng.random() < 0.35:
                px[x, 0] = CLEAR
                if px[x, 1][3]:
                    px[x, 1] = c(GREENS[3])
            else:
                px[x, 0] = c(GREENS[1] if rng.random() < 0.4 else GREENS[3])
                if px[x, 1][3]:
                    px[x, 1] = c(GREENS[3] if rng.random() < 0.6 else GREENS[2])
    if rng.random() < 0.35:  # florzinha
        x = rng.randrange(2, T - 2)
        if px[x, 1][3]:
            px[x, 1] = c(rng.choice(("e2b33c", "f7f6f0", "e0503a")))
    return img


# ================================================================ árvores e água


def leaves_base(rng):
    img = new()
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, T - 1, T - 1], fill=c(GREENS[1]))
    for _ in range(10):  # tufos com luz de cima-esquerda
        x, y = rng.randrange(-3, 14), rng.randrange(-3, 14)
        r = rng.choice((4, 5, 5, 6))
        d.ellipse([x, y, x + r, y + r], fill=c(GREENS[2]))
        d.arc([x, y, x + r, y + r], 190, 280, fill=c(GREENS[3]))
        d.arc([x, y, x + r, y + r], 10, 120, fill=c(GREENS[0]))
    if rng.random() < 0.25:  # fruto
        x, y = rng.randrange(3, 12), rng.randrange(3, 12)
        d.point([x, y], fill=c("b8322a"))
        d.point([x, y - 1], fill=c("e0503a"))
    return img


def leaves_edges(base: Image.Image, mask: int) -> Image.Image:
    """Copa recortada: mordidas na borda exposta, contorno escuro embaixo, luz em cima."""
    img = base.copy()
    px = img.load()

    def wave(i: int, seed: int) -> int:
        # Recorte ondulado de 1 a 4 px: tufos de folhas, não uma linha reta.
        return 1 + int(1.6 * (1 + math.sin(i * 0.9 + seed)) + (1 if (i * 7 + seed) % 5 == 0 else 0))

    for x in range(T):
        for y in range(T):
            cut = (
                (mask & TOP and y < wave(x, 1))
                or (mask & BOTTOM and y > T - 1 - wave(x, 4))
                or (mask & LEFT and x < wave(y, 2))
                or (mask & RIGHT and x > T - 1 - wave(y, 3))
            )
            if cut:
                px[x, y] = CLEAR
    r = 6  # cantos arredondados de raio 6 onde dois lados vizinhos estão expostos
    corners = [(TOP | LEFT, r, r), (TOP | RIGHT, T - 1 - r, r), (BOTTOM | LEFT, r, T - 1 - r),
               (BOTTOM | RIGHT, T - 1 - r, T - 1 - r)]
    for bits, cx, cy in corners:
        if mask & bits != bits:
            continue
        for y in range(T):
            for x in range(T):
                in_corner = (x <= cx if bits & LEFT else x >= cx) and (y <= cy if bits & TOP else y >= cy)
                if in_corner and (x - cx) ** 2 + (y - cy) ** 2 > r * r:
                    px[x, y] = CLEAR
    snap = img.copy().load()
    for y in range(T):
        for x in range(T):
            if snap[x, y][3] == 0:
                continue
            nb = [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
            if any(0 <= nx < T and 0 <= ny < T and snap[nx, ny][3] == 0 for nx, ny in nb):
                above_open = y > 0 and snap[x, y - 1][3] == 0
                px[x, y] = c(GREENS[3] if above_open else GREENS[0])
    return img


def tronco(rng, base: bool = False):
    img = new()
    d = ImageDraw.Draw(img)
    d.rectangle([5, 0, 10, T - 1], fill=c("57432f"))
    d.line([5, 0, 6, 0], fill=c("74593d"))
    d.line([5, 0, 5, T - 1], fill=c("74593d"))
    d.line([6, 0, 6, T - 1], fill=c("74593d"))
    d.line([10, 0, 10, T - 1], fill=c("3d3128"))
    d.line([4, 0, 4, T - 1], fill=c("2b231d"))
    d.line([11, 0, 11, T - 1], fill=c("2b231d"))
    for x in (7, 9):  # sulcos da casca
        y = rng.randrange(-4, 3)
        while y < T:
            seg = rng.randrange(3, 6)
            d.line([x, y, x, y + seg], fill=c("3d3128"))
            y += seg + rng.randrange(2, 4)
    if rng.random() < 0.35:  # nó
        y = rng.randrange(3, 11)
        d.ellipse([7, y, 9, y + 2], fill=c("3d3128"), outline=c("2b231d"))
    if rng.random() < 0.3:  # musgo
        y = rng.randrange(4, 13)
        d.line([5, y, 6, y + 1], fill=c("4f8a4a"))
    if base:  # raízes abrindo no chão
        for side in (-1, 1):
            x = 4 if side < 0 else 11
            for i, y in enumerate(range(T - 5, T)):
                reach = i // 2 + 1
                d.line([x, y, x + side * reach, y], fill=c("57432f"))
                d.point([x + side * reach, y], fill=c("2b231d"))
        d.line([2, T - 1, 13, T - 1], fill=c("3d3128"))
    return img


def agua(rng, surface: bool = False):
    img = new()
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, T - 1, T - 1], fill=c("2d4f80", 185))
    for y in range(8, T):  # mais escura no fundo
        d.line([0, y, T - 1, y], fill=c("1b2a4a", 30 + (y - 8) * 8))
    for _ in range(3):
        x, y = rng.randrange(0, 11), rng.randrange(4, 14)
        d.line([x, y, x + rng.randrange(2, 5), y], fill=c("4f86c0", 200))
    if surface:
        d.rectangle([0, 0, T - 1, 3], fill=CLEAR)
        for x in range(T):
            wave = 4 + (1 if math.sin(x * 0.8 + rng.random()) > 0.6 else 0)
            d.point([x, wave], fill=c("c8f0ff", 230))
            d.point([x, wave + 1], fill=c("9fd3f0", 210))
            d.line([x, wave + 2, x, wave + 3], fill=c("4f86c0", 200))
    return img


# ================================================================ minérios


def ore_clusters(rng, colors, count, size, sparkle=None) -> Image.Image:
    img = new()
    d = ImageDraw.Draw(img)
    dark, mid, light = colors
    for _ in range(count):
        w = rng.randint(*size)
        h = max(2, w - rng.randint(0, 1))
        x, y = rng.randrange(1, T - w), rng.randrange(1, T - h)
        d.ellipse([x - 1, y - 1, x + w, y + h], fill=c("1b1714", 150))
        d.ellipse([x, y, x + w - 1, y + h - 1], fill=c(mid))
        d.line([x + 1, y + h - 1, x + w - 2, y + h - 1], fill=c(dark))
        d.line([x + w - 1, y + 1, x + w - 1, y + h - 2], fill=c(dark))
        d.point([x + 1, y], fill=c(light))
        if w > 3:
            d.point([x + 1, y + 1], fill=c(light))
        if sparkle and rng.random() < 0.5:
            d.point([x + 1, y], fill=c(sparkle))
    return img


def malaquita(rng):
    img = new()
    d = ImageDraw.Draw(img)
    for _ in range(3):  # nódulos com faixas concêntricas, como a malaquita real
        x, y = rng.randrange(0, 9), rng.randrange(0, 9)
        r = rng.randint(5, 7)
        d.ellipse([x - 1, y - 1, x + r, y + r], fill=c("1b1714", 140))
        d.ellipse([x, y, x + r - 1, y + r - 1], fill=c("2f5a3a"))
        d.ellipse([x + 1, y + 1, x + r - 2, y + r - 2], fill=c("4f8a4a"))
        d.arc([x + 1, y + 1, x + r - 2, y + r - 2], 30, 150, fill=c("1f3a2a"))
        d.ellipse([x + 2, y + 2, x + r - 3, y + r - 3], outline=c("86b85a"))
        d.point([x + 2, y + 1], fill=c("f7f6f0"))
    return img


def limonita(rng):
    return ore_clusters(rng, ("5c3d12", "8a5a12", "b8801a"), 5, (3, 5), "e2b33c")


def carvao(rng):
    img = new()
    d = ImageDraw.Draw(img)
    for _ in range(4):
        x, y = rng.randrange(0, 11), rng.randrange(0, 12)
        pts = [(x, y + 2), (x + 2, y), (x + 5, y + 1), (x + 6, y + 4), (x + 3, y + 5), (x, y + 4)]
        d.polygon(pts, fill=c("1b1714"), outline=c("0f0d0c"))
        d.line([x + 2, y + 1, x + 4, y + 1], fill=c("4a5058"))
        d.point([x + 2, y + 1], fill=c("949ca3"))
    return img


def hematita(rng):
    img = new()
    px = img.load()
    for base in (rng.randrange(1, 4), rng.randrange(8, 10)):
        x0, x1 = rng.randrange(0, 3), rng.randrange(12, 16)
        y = base
        for x in range(x0, x1):
            if rng.random() < 0.3:
                y = max(0, min(T - 5, y + rng.choice((-1, 1))))
            thick = 2 + (1 if rng.random() < 0.5 else 0)
            px[x, y] = c("e0503a" if rng.random() < 0.15 else "b8322a")
            for k in range(1, thick):
                px[x, y + k] = c("8a2224")
            px[x, y + thick] = c("5e161a")
            px[x, y + thick + 1] = c("1b1714", 120)
        px[rng.randrange(x0 + 1, x1 - 1), base + 1] = c("bfc5c9")
        px[rng.randrange(x0 + 1, x1 - 1), base + 1] = c("e3e6e4")
    return img


def quartzo(rng):
    img = new()
    d = ImageDraw.Draw(img)
    for _ in range(3):
        x, y = rng.randrange(1, 11), rng.randrange(7, 14)
        h = rng.randint(4, 7)
        d.polygon([(x - 1, y + 1), (x + 5, y + 1), (x + 4, y), (x, y)], fill=c("1b1714", 140))
        d.polygon([(x, y), (x, y - h + 1), (x + 2, y - h - 1), (x + 4, y - h + 1), (x + 4, y)],
                  fill=c("e3e6e4"), outline=c("949ca3"))
        d.line([x + 1, y - 1, x + 1, y - h + 1], fill=c("f7f6f0"))
        d.line([x + 3, y - 1, x + 3, y - h + 2], fill=c("bfc5c9"))
        d.point([x + 2, y - h], fill=c("c8f0ff"))
    return img


def acantita(rng):
    img = ore_clusters(rng, ("2d4f80", "bfc5c9", "f7f6f0"), 4, (3, 4), "c8f0ff")
    d = ImageDraw.Draw(img)
    for _ in range(3):
        d.point([rng.randrange(2, 14), rng.randrange(2, 14)], fill=c("9fd3f0"))
    return img


def silex(rng):
    img = new()
    d = ImageDraw.Draw(img)
    for _ in range(2):
        x, y = rng.randrange(1, 8), rng.randrange(1, 8)
        w, h = rng.randint(5, 7), rng.randint(4, 6)
        d.ellipse([x - 1, y, x + w + 1, y + h + 1], fill=c("1b1714", 120))
        d.ellipse([x, y, x + w, y + h], fill=c("2b231d"), outline=c("1b1714"))
        d.arc([x, y, x + w, y + h], 30, 150, fill=c("94744f"))  # córtex claro embaixo
        d.arc([x + 1, y + 1, x + w - 1, y + h - 1], 190, 270, fill=c("6b737c"))  # fratura brilhante
        d.point([x + 2, y + 2], fill=c("e3e6e4"))
    return img


# ================================================================ paredes e sombras


def wall_shadow(mask: int) -> Image.Image:
    """Bits = lados com bloco sólido vizinho. A sombra entra uns pixels na parede."""
    img = new()
    px = img.load()
    fade = [120, 75, 40, 18]
    for y in range(T):
        for x in range(T):
            alpha = 0
            if mask & TOP and y < 4:
                alpha = max(alpha, fade[y])
            if mask & BOTTOM and y > T - 3:
                alpha = max(alpha, fade[T - y + 1])
            if mask & LEFT and x < 3:
                alpha = max(alpha, fade[x + 1])
            if mask & RIGHT and x > T - 4:
                alpha = max(alpha, fade[T - x])
            if alpha:
                px[x, y] = c("0f0d0c", alpha)
    return img


def wall_of(img: Image.Image) -> Image.Image:
    """Versão de parede: escurece e puxa para o frio, depois volta para a paleta."""
    out = img.copy()
    px = out.load()
    tr, tg, tb = PAL["1b2a4a"]
    for y in range(T):
        for x in range(T):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = nearest((int(r * 0.42 + tr * 0.35), int(g * 0.42 + tg * 0.35), int(b * 0.42 + tb * 0.35))) + (255,)
    return out


# ================================================================ atlas

# nome: (pintor, contorno, brilho, sombra)
SOLIDS = {
    "terra": (terra, "3d3128", "94744f", "57432f"),
    "grama": (terra, "3d3128", "94744f", "57432f"),
    "argila": (argila, "74593d", "e2b33c", "94744f"),
    "areia": (areia, "94744f", "fbeeb0", "b8956a"),
    "cascalho": (cascalho, "2b231d", "94744f", "3d3128"),
    "calcario": (calcario, "4a5058", "e3e6e4", "6b737c"),
    "xisto": (xisto, "2b231d", "bfc5c9", "4a5058"),
    "rocha_base": (rocha_base, "0f0d0c", "3d3128", "0f0d0c"),
    "tijolo": (tijolo, "3a0f12", "e0503a", "5e161a"),
    "tijolo_refratario": (tijolo_refratario, "5c3d12", "fbeeb0", "94744f"),
    "argamassa": (argamassa, "4a5058", "f7f6f0", "6b737c"),
    "vidro": (vidro, "4f86c0", "f7f6f0", "2d4f80"),
    "vidro_de_tempestade": (vidro_de_tempestade, "2d4f80", "c8f0ff", "1b2a4a"),
    "fulgurito": (fulgurito, "57432f", "c8f0ff", "74593d"),
}
## Blocos construídos não viram parede de fundo (só as rochas naturais).
BUILT = {"tijolo", "tijolo_refratario", "argamassa", "vidro", "vidro_de_tempestade"}
ORES = {
    "malaquita": malaquita, "limonita": limonita, "carvao_mineral": carvao, "hematita": hematita,
    "quartzo": quartzo, "acantita": acantita, "silex": silex,
    "cassiterita": lambda rng: ore_clusters(rng, ("0f0d0c", "2b231d", "94744f"), 6, (2, 3)),
    "ouro_aluvial": lambda rng: ore_clusters(rng, ("8a5a12", "e2b33c", "fbeeb0"), 5, (2, 3), "f7f6f0"),
}
OTHER_ROWS = ["folhas", "tronco", "tronco_base", "agua", "agua_topo"]


def build_tiles() -> dict:
    rows = list(SOLIDS) + OTHER_ROWS
    atlas = new(T * MASKS * VARIANTS, T * len(rows))
    for row, name in enumerate(rows):
        for v in range(VARIANTS):
            seed = f"{name}-{v}"
            base = None
            if name in SOLIDS:
                painter, outline, light, shade = SOLIDS[name]
                base = painter(random.Random(f"terra-{v}" if name == "grama" else seed))
            elif name == "folhas":
                base = leaves_base(random.Random(seed))
            for mask in range(MASKS):
                rng = random.Random(f"{seed}-{mask}")
                if name == "grama":
                    tile = grass_edges(base, mask, rng)
                elif name in SOLIDS:
                    tile = apply_edges(base, mask, outline, light, shade)
                elif name == "folhas":
                    tile = leaves_edges(base, mask)
                elif name in ("tronco", "tronco_base"):
                    tile = tronco(random.Random(seed), base=name == "tronco_base")
                else:
                    tile = agua(random.Random(seed), surface=name == "agua_topo")
                atlas.paste(tile, ((mask * VARIANTS + v) * T, row * T))

    natural = [name for name in SOLIDS if name not in BUILT]
    walls = new(T * VARIANTS, T * len(natural))
    for row, name in enumerate(natural):
        for v in range(VARIANTS):
            walls.paste(wall_of(SOLIDS[name][0](random.Random(f"{name}-{v}"))), (v * T, row * T))

    ores = new(T * MASKS * VARIANTS, T * len(ORES))
    for row, (name, painter) in enumerate(ORES.items()):
        for v in range(VARIANTS):
            art = painter(random.Random(f"{name}-{v}"))
            for mask in range(MASKS):
                tile = art.copy()
                tpx = tile.load()
                for x, y in corner_cuts(mask):
                    tpx[x, y] = CLEAR
                ores.paste(tile, ((mask * VARIANTS + v) * T, row * T))

    shadows = new(T * MASKS, T)
    for mask in range(MASKS):
        shadows.paste(wall_shadow(mask), (mask * T, 0))

    out = ART / "tiles"
    out.mkdir(parents=True, exist_ok=True)
    for old in ("bordas.png", "bordas.png.import"):
        if (out / old).exists():
            (out / old).unlink()
    atlas.save(out / "tiles.png")
    walls.save(out / "paredes.png")
    ores.save(out / "minerios.png")
    shadows.save(out / "sombras.png")
    meta = {
        "tamanho": T,
        "variacoes": VARIANTS,
        "mascaras": MASKS,
        "coluna": "mascara * variacoes + variacao",
        "mascara_bits": {"topo": TOP, "direita": RIGHT, "baixo": BOTTOM, "esquerda": LEFT},
        "tiles": {name: {"linha": i} for i, name in enumerate(rows)},
        "paredes": {name: {"linha": i} for i, name in enumerate(natural)},
        "minerios": {name: {"linha": i} for i, name in enumerate(ORES)},
        "observacao": "Gerado por tools/art/gerar_arte.py. Minérios vão por cima da rocha da camada.",
    }
    (out / "tiles.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return {"atlas": atlas, "walls": walls, "ores": ores, "shadows": shadows, "rows": rows}


# ================================================================ fundo (paralaxe)

BG_W, BG_H = 640, 360
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def dither_band(img: Image.Image, y0: int, y1: int, top: str, bottom: str) -> None:
    """Transição pontilhada entre duas cores (estilo pixel art, sem degradê contínuo)."""
    px = img.load()
    for y in range(y0, y1):
        t = (y - y0) / max(1, y1 - y0)
        for x in range(img.width):
            px[x, y] = c(bottom if t * 16 > BAYER[y % 4][x % 4] else top)


def ridge(rng: random.Random, width: int, base: int, waves: list[tuple[int, float]]) -> list[int]:
    """Linha de relevo que fecha emendada (repete sem costura na largura)."""
    phases = [rng.random() * 6.28 for _ in waves]
    return [int(base - sum(a * math.sin(x * f * 2 * math.pi / width + p) for (f, a), p in zip(waves, phases)))
            for x in range(width)]


def build_background() -> dict:
    out = ART / "fundo"
    out.mkdir(parents=True, exist_ok=True)
    rng = random.Random("fundo")

    sky = new(BG_W, BG_H)
    d = ImageDraw.Draw(sky)
    bands = [("4f86c0", 0), ("9fd3f0", 130), ("c8f0ff", 290)]
    for i, (color, y0) in enumerate(bands):
        y1 = bands[i + 1][1] if i + 1 < len(bands) else BG_H
        d.rectangle([0, y0, BG_W - 1, y1 - 1], fill=c(color))
        if i + 1 < len(bands):  # transição pontilhada curta entre faixas
            dither_band(sky, y1 - 10, y1 + 10, color, bands[i + 1][0])
    sky.save(out / "ceu.png")

    # Montanhas distantes: claras e azuladas (perspectiva atmosférica), com neve no alto.
    far = new(BG_W * 2, 240)
    d = ImageDraw.Draw(far)
    top = ridge(rng, far.width, 110, [(3, 24), (7, 11), (17, 4)])
    for x, y in enumerate(top):
        d.line([x, y, x, far.height - 1], fill=c("949ca3"))
        d.line([x, y + 24, x, far.height - 1], fill=c("6b737c"))
        if y < 98:
            d.line([x, y, x, y + (98 - y) // 2 + 1], fill=c("e3e6e4"))
            d.point([x, y], fill=c("f7f6f0"))
        slope = top[(x + 1) % far.width] - y
        if slope > 0:  # encosta voltada para a sombra
            d.line([x, y + 2, x, y + 8], fill=c("6b737c"))
    far.save(out / "montanhas.png")

    # Colinas com mata, mais perto.
    near = new(BG_W * 2, 560)
    d = ImageDraw.Draw(near)
    top = ridge(rng, near.width, 70, [(4, 14), (9, 6), (23, 3)])
    for x, y in enumerate(top):
        d.line([x, y, x, near.height - 1], fill=c("2f5a3a"))
        d.line([x, y + 28, x, near.height - 1], fill=c("1f3a2a"))
    for _ in range(200):
        x = rng.randrange(near.width)
        y = top[x] - rng.randint(1, 4)
        r = rng.randint(4, 8)
        for dx in (-near.width, 0, near.width):  # desenha também nas pontas para emendar
            d.ellipse([x + dx - r, y - r, x + dx + r, y + r], fill=c("2f5a3a"))
            d.arc([x + dx - r, y - r, x + dx + r, y + r], 200, 290, fill=c("4f8a4a"))
    near.save(out / "colinas.png")

    clouds = new(BG_W * 2, 120)
    d = ImageDraw.Draw(clouds)
    for _ in range(9):
        cx, cy = rng.randrange(60, clouds.width - 60), rng.randrange(24, 90)
        for _ in range(6):
            dx, dy, r = rng.randint(-28, 28), rng.randint(-5, 5), rng.randint(8, 15)
            d.ellipse([cx + dx - r, cy + dy - r, cx + dx + r, cy + dy + r // 2], fill=c("f7f6f0"))
        d.rectangle([cx - 30, cy + 4, cx + 30, cy + 8], fill=c("e3e6e4"))
    px = clouds.load()
    for y in range(clouds.height - 1):
        for x in range(clouds.width):
            if px[x, y][3] and px[x, y + 1][3] == 0:
                px[x, y] = c("bfc5c9")
    clouds.save(out / "nuvens.png")
    return {"sky": sky, "far": far, "near": near, "clouds": clouds}


# ================================================================ personagem

PW, PH = 16, 32
ANIMS = [("parado", 4), ("andar", 8), ("pular", 2)]
PARTS = ["braco_tras", "pernas", "tronco", "cabeca", "cabelo", "braco_frente"]
OUTLINE = "1b1714"
SKIN = {"sombra": "94744f", "base": "b8956a", "luz": "fbeeb0"}
TUNIC = {"sombra": "5e161a", "base": "8a2224", "luz": "b8322a"}
LEATHER = {"sombra": "3d3128", "base": "57432f", "luz": "74593d"}
PANTS = {"sombra": "1b1714", "base": "2b231d", "luz": "3d3128"}
HAIR = {"sombra": "1b1714", "base": "2b231d", "luz": "57432f"}


def pose(anim: str, frame: int) -> dict:
    p = {"bob": 0, "fl": 0, "bl": 0, "fa": 0, "ba": 0, "lift_f": 0, "lift_b": 0, "arms": 0}
    if anim == "parado":
        p["bob"] = (0, 0, 1, 1)[frame]
    elif anim == "andar":
        swing = (0, 2, 3, 2, 0, -2, -3, -2)[frame]
        p.update(fl=swing, bl=-swing, fa=-swing // 2, ba=(swing + 1) // 2)
        p["bob"] = (0, 1, 1, 0, 0, 1, 1, 0)[frame]
        p["lift_f"] = 1 if frame in (1, 2) else 0
        p["lift_b"] = 1 if frame in (5, 6) else 0
    elif anim == "pular":
        if frame == 0:
            p.update(fl=2, bl=-1, lift_f=3, lift_b=1, arms=1)
        else:
            p.update(fl=1, bl=-2, arms=-1)
    return p


def draw_leg(d, hip_x: int, foot_dx: int, lift: int, back: bool) -> None:
    hip_y, foot_y = 21, 31 - lift
    for y in range(hip_y, foot_y - 2):
        t = (y - hip_y) / max(1, foot_y - hip_y)
        x = hip_x + round(foot_dx * t)
        d.point([x, y], fill=c(PANTS["base"] if back else PANTS["luz"]))
        d.point([x + 1, y], fill=c(PANTS["sombra"] if back else PANTS["base"]))
        d.point([x + 2, y], fill=c(PANTS["sombra"]))
    fx = hip_x + foot_dx
    boot = "2b231d" if back else "3d3128"
    d.rectangle([fx, foot_y - 3, fx + 2, foot_y - 1], fill=c(boot))  # cano da bota
    d.line([fx, foot_y - 3, fx + 2, foot_y - 3], fill=c("3d3128" if back else "57432f"))
    d.point([fx + 3, foot_y - 1], fill=c(boot))  # bico
    d.line([fx, foot_y, fx + 3, foot_y], fill=c("0f0d0c"))  # sola
    if not back:
        d.point([fx + 1, foot_y - 2], fill=c("74593d"))  # cadarço


def draw_arm(d, sx: int, hand_dx: int, bob: int, up: int, back: bool) -> None:
    sleeve_l = TUNIC["base"] if back else TUNIC["luz"]
    skin = SKIN["sombra"] if back else SKIN["base"]
    top = 12 + bob
    length = 6 if up == 0 else 5
    last = (sx, top)
    for i in range(length):
        x = sx + round(hand_dx * i / length)
        y = top + i - (i * 2 // 3 if up > 0 else 0)
        last = (x, y)
        d.point([x, y], fill=c(sleeve_l))
        d.point([x + 1, y], fill=c(TUNIC["sombra"]))
    hx, hy = last[0] + (1 if up < 0 else 0), last[1] + 1
    d.line([hx, hy, hx + 1, hy], fill=c(TUNIC["sombra"]))  # punho
    d.rectangle([hx, hy + 1, hx + 1, hy + 2], fill=c(skin))
    d.point([hx + 1, hy + 2], fill=c(SKIN["sombra"]))


def draw_part(part: str, anim: str, frame: int) -> Image.Image:
    img = new(PW, PH)
    d = ImageDraw.Draw(img)
    p = pose(anim, frame)
    b = p["bob"]
    if part == "pernas":
        draw_leg(d, 5, p["bl"], p["lift_b"], True)
        draw_leg(d, 8, p["fl"], p["lift_f"], False)
    elif part == "tronco":
        top = 11 + b
        d.rectangle([5, top, 10, 20], fill=c(TUNIC["base"]))
        d.line([5, top + 1, 5, 20], fill=c(TUNIC["luz"]))
        d.line([10, top + 1, 10, 20], fill=c(TUNIC["sombra"]))
        d.line([4, 20, 11, 20], fill=c(TUNIC["base"]))  # barra abrindo
        d.line([4, 21, 11, 21], fill=c(TUNIC["sombra"]))
        d.point([4, 20], fill=c(TUNIC["luz"]))
        d.line([7, top, 9, top], fill=c(SKIN["sombra"]))  # gola em V
        d.point([8, top + 1], fill=c(SKIN["sombra"]))
        for i in range(6):  # alça da bolsa, do ombro ao quadril
            d.point([10 - i, top + 1 + i], fill=c(LEATHER["luz"] if i % 2 == 0 else LEATHER["base"]))
        belt = 17 + b
        d.line([5, belt, 10, belt], fill=c(LEATHER["sombra"]))
        d.point([8, belt], fill=c("e2b33c"))  # fivela
        d.point([9, belt], fill=c("b8801a"))
        d.rectangle([4, belt + 1, 5, belt + 3], fill=c(LEATHER["base"]))  # bolsa no quadril
        d.point([4, belt + 1], fill=c(LEATHER["luz"]))
        d.point([5, belt + 3], fill=c(LEATHER["sombra"]))
        d.line([10, belt + 1, 10, belt + 3], fill=c("4f8a4a"))  # frasco verde no cinto
        d.point([10, belt + 1], fill=c("c8f0ff"))
        d.point([10, belt], fill=c("74593d"))  # rolha
    elif part == "cabeca":
        top = 4 + b
        d.rectangle([5, top, 10, top + 6], fill=c(SKIN["base"]))
        d.line([5, top + 6, 10, top + 6], fill=c(SKIN["sombra"]))  # queixo
        d.line([5, top + 1, 5, top + 5], fill=c(SKIN["sombra"]))
        d.line([6, top + 3, 6, top + 4], fill=c(SKIN["sombra"]))  # orelha
        d.point([9, top + 3], fill=c("f7f6f0"))  # olho
        d.point([10, top + 3], fill=c("0f0d0c"))
        d.line([9, top + 2, 10, top + 2], fill=c(HAIR["base"]))  # sobrancelha
        d.point([11, top + 4], fill=c(SKIN["base"]))  # nariz
        d.point([11, top + 5], fill=c(SKIN["sombra"]))
        d.point([10, top + 5], fill=c(SKIN["sombra"]))  # boca
        d.point([8, top + 1], fill=c(SKIN["luz"]))  # luz na testa
    elif part == "cabelo":
        top = 3 + b
        d.rectangle([5, top, 10, top + 1], fill=c(HAIR["base"]))
        d.rectangle([4, top + 1, 6, top + 5], fill=c(HAIR["base"]))
        d.line([6, top, 9, top], fill=c(HAIR["luz"]))
        d.point([7, top + 1], fill=c(HAIR["luz"]))
        d.point([10, top + 2], fill=c(HAIR["base"]))  # franja
        d.point([4, top + 5], fill=c(HAIR["sombra"]))
        d.point([5, top + 6], fill=c(HAIR["sombra"]))
        d.point([5, top + 3], fill=c(HAIR["luz"]))
    elif part == "braco_tras":
        draw_arm(d, 5, p["ba"], b, p["arms"], True)
    elif part == "braco_frente":
        draw_arm(d, 8, p["fa"], b, p["arms"], False)
    return img


def outline_of(img: Image.Image) -> Image.Image:
    out = new(*img.size)
    src, dst = img.load(), out.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3]:
                continue
            if any(0 <= x + dx < w and 0 <= y + dy < h and src[x + dx, y + dy][3]
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                dst[x, y] = c(OUTLINE)
    return out


def build_character() -> Image.Image:
    cols = max(n for _, n in ANIMS)
    sheets = {part: new(PW * cols, PH * len(ANIMS)) for part in PARTS + ["contorno"]}
    composite = new(PW * cols, PH * len(ANIMS))
    for row, (anim, frames) in enumerate(ANIMS):
        for frame in range(frames):
            full = new(PW, PH)
            for part in PARTS:
                piece = draw_part(part, anim, frame)
                sheets[part].paste(piece, (frame * PW, row * PH))
                full.alpha_composite(piece)
            line = outline_of(full)
            sheets["contorno"].paste(line, (frame * PW, row * PH))
            line.alpha_composite(full)
            composite.paste(line, (frame * PW, row * PH))
    out = ART / "personagem"
    out.mkdir(parents=True, exist_ok=True)
    for part, sheet in sheets.items():
        sheet.save(out / f"{part}.png")
    meta = {
        "quadro": [PW, PH],
        "colunas": cols,
        "animacoes": {anim: {"linha": row, "quadros": frames} for row, (anim, frames) in enumerate(ANIMS)},
        "partes": ["contorno"] + PARTS,
        "pes": [PW // 2, PH],
        "observacao": "Partes empilhadas na ordem de 'partes'. Armadura, ferramenta e efeito entram nas Ondas 3-5.",
    }
    (out / "personagem.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return composite


# ================================================================ prancha e verificação


def check_palette(*images: Image.Image) -> None:
    allowed = set(PAL.values())
    for img in images:
        pixels = img.get_flattened_data() if hasattr(img, "get_flattened_data") else img.getdata()
        for r, g, b, a in pixels:
            if a and (r, g, b) not in allowed:
                raise SystemExit(f"cor fora da paleta encontrada: {(r, g, b)}")


def board(t: dict, composite: Image.Image) -> None:
    """Prancha: um barranco montado com as máscaras, minérios na rocha e o personagem."""
    scale = 3
    atlas, rows = t["atlas"], t["rows"]

    def tile(name: str, mask: int, v: int = 0) -> Image.Image:
        r = rows.index(name)
        x = (mask * VARIANTS + v) * T
        return atlas.crop((x, r * T, x + T, (r + 1) * T))

    cols, height = 14, 8
    scene = t["sky"].crop((0, 170, T * cols, 170 + T * height)).copy()
    heights = [4, 4, 4, 5, 5, 6, 6, 6, 5, 5, 4, 4, 4, 4]
    solid = {}
    for x, h in enumerate(heights):
        for y in range(h, height):
            solid[(x, y)] = "grama" if y == h else ("calcario" if y >= 7 else "terra")
    for (x, y), name in solid.items():
        m = (TOP if (x, y - 1) not in solid else 0)
        m |= RIGHT if x < cols - 1 and (x + 1, y) not in solid else 0
        m |= LEFT if x > 0 and (x - 1, y) not in solid else 0
        scene.alpha_composite(tile(name, m, (x * 3 + y) % VARIANTS), (x * T, y * T))
    tx = 2
    scene.alpha_composite(tile("tronco_base", 0), (tx * T, 3 * T))
    scene.alpha_composite(tile("tronco", 0), (tx * T, 2 * T))
    canopy = {(1, 0), (2, 0), (3, 0), (1, 1), (2, 1), (3, 1)}
    for lx, ly in canopy:
        m = (TOP if (lx, ly - 1) not in canopy else 0) | (BOTTOM if (lx, ly + 1) not in canopy else 0)
        m |= (LEFT if (lx - 1, ly) not in canopy else 0) | (RIGHT if (lx + 1, ly) not in canopy else 0)
        scene.alpha_composite(tile("folhas", m, (lx + ly) % VARIANTS), (lx * T, ly * T))
    scene.alpha_composite(composite.crop((PW, PH, 2 * PW, 2 * PH)), (8 * T, 6 * T - PH))

    ore_row = new(T * len(ORES), T)
    hosts = {"malaquita": "calcario", "limonita": "terra", "carvao_mineral": "calcario", "hematita": "xisto",
             "quartzo": "xisto", "acantita": "xisto", "silex": "terra",
             "cassiterita": "cascalho", "ouro_aluvial": "cascalho"}
    for i, name in enumerate(ORES):
        ore_row.alpha_composite(tile(hosts[name], 0, i % VARIANTS), (i * T, 0))
        ore_row.alpha_composite(t["ores"].crop((i % VARIANTS * T, i * T, (i % VARIANTS + 1) * T, (i + 1) * T)), (i * T, 0))

    pad = 10
    parts = [scene, ore_row, composite]
    width = max(p.width for p in parts) * scale + pad * 2
    height_px = sum(p.height * scale + pad for p in parts) + pad
    out = Image.new("RGBA", (width, height_px), c("1b1714"))
    y = pad
    for p in parts:
        out.alpha_composite(p.resize((p.width * scale, p.height * scale), Image.NEAREST), (pad, y))
        y += p.height * scale + pad
    (ROOT / "docs" / "img").mkdir(parents=True, exist_ok=True)
    out.save(ROOT / "docs" / "img" / "arte-base.png")


def main() -> None:
    t = build_tiles()
    bg = build_background()
    t.update(bg)
    composite = build_character()
    import gerar_itens  # depois dos tiles: os ícones de bloco e minério saem do atlas

    items = gerar_itens.build(t)
    check_palette(t["atlas"], t["walls"], t["ores"], t["shadows"], composite, *bg.values(),
                  items["icons"], items["objects"], items["cracks"], items["cursor"], items["slot"])
    board(t, composite)
    print(f"OK: {items['count']} ícones de itens, tocha animada, rachaduras e interface")
    print(f"OK: {len(t['rows'])} tiles x {MASKS} máscaras, {len(ORES)} minérios, fundo em 4 planos, "
          f"personagem com {len(PARTS)} partes")


if __name__ == "__main__":
    main()
