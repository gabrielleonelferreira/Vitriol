#!/usr/bin/env python3
"""Gera a arte base do jogo (tiles e personagem) só com as cores da paleta oficial.

Uso (na raiz do repositório):
    pip install pillow
    python3 tools/art/gerar_arte.py

Gera:
    art/tiles/tiles.png        atlas 16x16: uma linha por tile, colunas 0-3 frente, 4-7 parede
    art/tiles/minerios.png     atlas de minérios desenhados por cima da rocha (fundo transparente)
    art/tiles/bordas.png       16 máscaras de borda (contorno e brilho onde o bloco encosta no ar)
    art/tiles/tiles.json       mapa nome -> linha do atlas
    art/personagem/<parte>.png folhas de animação 16x32 por parte do corpo
    art/personagem/personagem.json  quadros por animação e ordem das partes
    docs/img/arte-base.png     prancha de referência

A arte é determinística: rodar de novo gera os mesmos arquivos.
"""

from __future__ import annotations

import json
import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "art"
T = 16
VARIANTS = 4

PALETTE = [line.strip() for line in (ART / "paleta" / "vitriol.hex").read_text().split() if line.strip()]
PAL = {h: tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) for h in PALETTE}


def c(hexcode: str, alpha: int = 255) -> tuple[int, int, int, int]:
    if hexcode not in PAL:
        raise ValueError(f"cor fora da paleta: {hexcode}")
    return PAL[hexcode] + (alpha,)


# ---------------------------------------------------------------- utilidades

def new_tile() -> Image.Image:
    return Image.new("RGBA", (T, T), (0, 0, 0, 0))


def fill_noise(img: Image.Image, ramp: list[str], rng: random.Random, weights: list[float], passes: int = 2) -> None:
    """Preenche com tons da rampa sorteados por peso, em blocos de 1-2 px para não virar chiado."""
    px = img.load()
    for y in range(T):
        for x in range(T):
            px[x, y] = c(rng.choices(ramp, weights)[0])
    # Agrupa: cada pixel tem chance de copiar o vizinho, formando manchas pequenas.
    for _ in range(passes):
        for y in range(T):
            for x in range(T):
                if rng.random() < 0.45:
                    nx, ny = (x + rng.choice((-1, 0, 1))) % T, (y + rng.choice((-1, 0, 1))) % T
                    px[x, y] = px[nx, ny]


def speck(img: Image.Image, color: str, count: int, rng: random.Random, size: int = 1) -> None:
    d = ImageDraw.Draw(img)
    for _ in range(count):
        x, y = rng.randrange(T), rng.randrange(T)
        d.rectangle([x, y, min(T - 1, x + size - 1), min(T - 1, y + size - 1)], fill=c(color))


def pebble(img: Image.Image, x: int, y: int, w: int, h: int, dark: str, mid: str, light: str) -> None:
    """Pedrinha com sombra embaixo e brilho em cima (luz vem de cima)."""
    d = ImageDraw.Draw(img)
    d.ellipse([x, y, x + w - 1, y + h - 1], fill=c(mid))
    d.line([x + 1, y + h - 1, x + w - 2, y + h - 1], fill=c(dark))
    if w > 2:
        d.point([x + 1, y], fill=c(light))


def darker(img: Image.Image, factor: float, tint: str = "1b2a4a") -> Image.Image:
    """Versão de parede: escurece e puxa para o frio, depois volta para a paleta."""
    out = img.copy()
    px = out.load()
    tr, tg, tb = PAL[tint]
    for y in range(T):
        for x in range(T):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            r = int(r * factor + tr * (1 - factor) * 0.6)
            g = int(g * factor + tg * (1 - factor) * 0.6)
            b = int(b * factor + tb * (1 - factor) * 0.6)
            px[x, y] = nearest((r, g, b)) + (a,)
    return out


def nearest(rgb: tuple[int, int, int]) -> tuple[int, int, int]:
    return min(PAL.values(), key=lambda p: sum((p[i] - rgb[i]) ** 2 for i in range(3)))


# ---------------------------------------------------------------- tiles de rocha e solo

def terra(rng):
    img = new_tile()
    fill_noise(img, ["57432f", "74593d", "94744f"], rng, [2.5, 8, 0.8], passes=5)
    speck(img, "3d3128", 3, rng)
    for _ in range(rng.randint(0, 1)):
        pebble(img, rng.randrange(1, 12), rng.randrange(1, 12), rng.choice((3, 4)), 3, "3d3128", "94744f", "b8956a")
    return img


def grama(rng):
    img = terra(rng)
    d = ImageDraw.Draw(img)
    greens = ["1f3a2a", "2f5a3a", "4f8a4a", "86b85a"]
    for x in range(T):
        depth = 3 + rng.choice((0, 0, 1, 1, 2))
        for y in range(depth):
            tone = greens[3] if y == 0 else greens[2] if y < depth - 1 else greens[1]
            d.point([x, y], fill=c(tone))
        d.point([x, depth], fill=c(greens[0]))
    return img


def argila(rng):
    img = new_tile()
    fill_noise(img, ["74593d", "94744f", "b8956a"], rng, [1, 5, 3])
    d = ImageDraw.Draw(img)
    for y in range(2, T, 5):
        x0 = rng.randrange(0, 4)
        d.line([x0, y, x0 + rng.randrange(6, 12), y], fill=c("74593d"))
        d.line([x0 + 2, y - 1, x0 + rng.randrange(4, 8), y - 1], fill=c("b8801a"))
    return img


def areia(rng):
    img = new_tile()
    fill_noise(img, ["94744f", "b8956a", "f2d36b", "fbeeb0"], rng, [1, 6, 2.5, 0.6])
    speck(img, "74593d", 4, rng)
    return img


def cascalho(rng):
    img = new_tile()
    fill_noise(img, ["3d3128", "57432f"], rng, [1, 2])
    for _ in range(9):
        w = rng.choice((3, 4, 5))
        pebble(img, rng.randrange(-1, 14), rng.randrange(-1, 14), w, rng.choice((3, 4)), "4a5058", rng.choice(("6b737c", "949ca3")), "bfc5c9")
    return img


def calcario(rng):
    img = new_tile()
    fill_noise(img, ["6b737c", "949ca3", "bfc5c9"], rng, [1.2, 6, 2.2], passes=4)
    d = ImageDraw.Draw(img)
    # Estratificação horizontal (camadas de sedimento).
    for y in (4 + rng.randrange(2), 11 + rng.randrange(2)):
        d.line([0, y, T - 1, y], fill=c("6b737c"))
    # Fósseis de concha.
    if rng.random() < 0.5:
        x, y = rng.randrange(2, 11), rng.randrange(2, 11)
        d.arc([x, y, x + 4, y + 3], 180, 360, fill=c("4a5058"))
    return img


def xisto(rng):
    img = new_tile()
    fill_noise(img, ["4a5058", "6b737c", "949ca3"], rng, [3, 6, 2])
    d = ImageDraw.Draw(img)
    # Foliação inclinada, típica da rocha metamórfica, com brilho de mica.
    for k in range(-T, T, 5):
        offset = k + rng.randrange(2)
        d.line([0, offset + 6, T - 1, offset], fill=c("4a5058"))
    speck(img, "e3e6e4", 3, rng)
    return img


def rocha_base(rng):
    img = new_tile()
    fill_noise(img, ["0f0d0c", "1b1714", "2b231d"], rng, [3, 5, 2])
    d = ImageDraw.Draw(img)
    x, y = rng.randrange(T), 0
    while y < T:
        nx = max(0, min(T - 1, x + rng.choice((-1, 0, 1))))
        d.line([x, y, nx, y + 2], fill=c("3d3128"))
        x, y = nx, y + 2
    return img


def tronco(rng):
    img = new_tile()
    d = ImageDraw.Draw(img)
    d.rectangle([4, 0, 11, T - 1], fill=c("57432f"))
    d.line([4, 0, 4, T - 1], fill=c("2b231d"))
    d.line([11, 0, 11, T - 1], fill=c("3d3128"))
    for x in (6, 9):
        y = rng.randrange(-4, 4)
        while y < T:
            seg = rng.randrange(3, 6)
            d.line([x, y, x, y + seg], fill=c("3d3128"))
            y += seg + rng.randrange(2, 4)
    d.line([5, 0, 5, T - 1], fill=c("74593d"))
    if rng.random() < 0.4:
        d.ellipse([7, rng.randrange(4, 10), 9, rng.randrange(11, 13)], outline=c("2b231d"))
    return img


def folhas(rng):
    img = new_tile()
    d = ImageDraw.Draw(img)
    greens = ["1f3a2a", "2f5a3a", "4f8a4a", "86b85a"]
    # Copa densa: base cheia e tufos por cima, com poucos furos para o céu.
    d.rectangle([0, 0, T - 1, T - 1], fill=c(greens[1]))
    for _ in range(3):
        x, y = rng.randrange(0, T), rng.randrange(0, T)
        d.point([x, y], fill=(0, 0, 0, 0))
    for _ in range(9):
        x, y = rng.randrange(-2, 14), rng.randrange(-2, 14)
        r = rng.choice((3, 4, 4, 5))
        d.ellipse([x, y, x + r, y + r], fill=c(greens[2]))
        d.arc([x, y, x + r, y + r], 200, 340, fill=c(greens[3]))
        d.arc([x, y, x + r, y + r], 20, 160, fill=c(greens[0]))
    return img


def agua(rng, surface: bool = False):
    img = new_tile()
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, T - 1, T - 1], fill=c("2d4f80", 190))
    for _ in range(3):
        x, y = rng.randrange(0, 12), rng.randrange(3, 15)
        d.line([x, y, x + rng.randrange(2, 5), y], fill=c("4f86c0", 200))
    if surface:
        d.rectangle([0, 0, T - 1, 3], fill=(0, 0, 0, 0))
        d.line([0, 4, T - 1, 4], fill=c("9fd3f0", 230))
        d.line([0, 5, T - 1, 5], fill=c("4f86c0", 210))
    return img


# ---------------------------------------------------------------- minérios (sobre a rocha)

def ore_clusters(rng, colors: tuple[str, str, str], count: int, size: tuple[int, int]) -> Image.Image:
    """Grãos arredondados: sombra embaixo, cor média, brilho em cima."""
    img = new_tile()
    dark, mid, light = colors
    for _ in range(count):
        w = rng.randint(*size)
        h = max(2, w - rng.randint(0, 1))
        x, y = rng.randrange(1, T - w), rng.randrange(1, T - h)
        d = ImageDraw.Draw(img)
        d.ellipse([x - 1, y - 1, x + w, y + h], fill=c("1b1714", 140))
        d.ellipse([x, y, x + w - 1, y + h - 1], fill=c(mid))
        d.line([x + 1, y + h - 1, x + w - 2, y + h - 1], fill=c(dark))
        d.point([x + 1, y + 1], fill=c(light))
    return img


def malaquita(rng):
    # Malaquita real tem faixas concêntricas verdes.
    img = ore_clusters(rng, ("2f5a3a", "4f8a4a", "86b85a"), 4, (3, 5))
    d = ImageDraw.Draw(img)
    for _ in range(2):
        x, y = rng.randrange(3, 10), rng.randrange(3, 10)
        d.arc([x, y, x + 5, y + 5], 200, 340, fill=c("1f3a2a"))
    return img


def limonita(rng):
    return ore_clusters(rng, ("5c3d12", "8a5a12", "b8801a"), 5, (3, 5))


def carvao(rng):
    img = new_tile()
    d = ImageDraw.Draw(img)
    for _ in range(4):
        x, y = rng.randrange(0, 11), rng.randrange(0, 12)
        pts = [(x, y + 2), (x + 2, y), (x + 5, y + 1), (x + 6, y + 4), (x + 3, y + 5), (x, y + 4)]
        d.polygon([(px_, py_) for px_, py_ in pts], fill=c("1b1714"), outline=c("0f0d0c"))
        d.point([x + 2, y + 1], fill=c("6b737c"))
    return img


def hematita(rng):
    # Ferro em faixas: bandas vermelho-escuras com brilho metálico.
    img = new_tile()
    px = img.load()
    for base in (rng.randrange(1, 4), rng.randrange(8, 11)):
        x0, x1 = rng.randrange(0, 3), rng.randrange(12, 16)
        y = base
        for x in range(x0, x1):
            if rng.random() < 0.3:
                y = max(0, min(T - 4, y + rng.choice((-1, 1))))
            thick = 2 + (1 if rng.random() < 0.5 else 0)
            px[x, y] = c("b8322a")
            for k in range(1, thick):
                px[x, y + k] = c("8a2224")
            px[x, y + thick] = c("5e161a")
        gx = rng.randrange(x0 + 1, x1 - 1)
        px[gx, base + 1] = c("bfc5c9")
    return img


def quartzo(rng):
    # Prismas: forma pontuda distingue do granulado da prata (acessibilidade).
    img = new_tile()
    d = ImageDraw.Draw(img)
    for _ in range(3):
        x, y = rng.randrange(1, 12), rng.randrange(4, 12)
        h = rng.randint(4, 7)
        d.polygon([(x, y), (x + 1, y - h), (x + 2, y - h - 1), (x + 3, y - h), (x + 4, y)], fill=c("e3e6e4"), outline=c("949ca3"))
        d.line([x + 1, y - 1, x + 1, y - h + 1], fill=c("f7f6f0"))
    return img


def acantita(rng):
    # Grãos metálicos redondos (prata): forma diferente dos prismas do quartzo.
    img = ore_clusters(rng, ("2d4f80", "bfc5c9", "f7f6f0"), 4, (3, 4))
    d = ImageDraw.Draw(img)
    for _ in range(2):
        x, y = rng.randrange(2, 13), rng.randrange(2, 13)
        d.point([x, y], fill=c("9fd3f0"))
    return img


def silex(rng):
    # Nódulos escuros com fratura brilhante (pederneira).
    img = new_tile()
    d = ImageDraw.Draw(img)
    for _ in range(2):
        x, y = rng.randrange(1, 9), rng.randrange(1, 9)
        w, h = rng.randint(5, 7), rng.randint(4, 6)
        d.ellipse([x, y, x + w, y + h], fill=c("2b231d"), outline=c("1b1714"))
        d.arc([x + 1, y + 1, x + w - 2, y + h - 2], 200, 280, fill=c("949ca3"))
    return img


# ---------------------------------------------------------------- bordas

def borda(mask: int) -> Image.Image:
    """Bits: 1 topo, 2 direita, 4 baixo, 8 esquerda expostos ao ar."""
    img = new_tile()
    d = ImageDraw.Draw(img)
    line = c("0f0d0c", 150)
    if mask & 1:
        d.line([0, 0, T - 1, 0], fill=line)
        d.line([0, 1, T - 1, 1], fill=c("f7f6f0", 55))
    if mask & 4:
        d.line([0, T - 1, T - 1, T - 1], fill=c("0f0d0c", 190))
        d.line([0, T - 2, T - 1, T - 2], fill=c("0f0d0c", 70))
    if mask & 2:
        d.line([T - 1, 0, T - 1, T - 1], fill=line)
    if mask & 8:
        d.line([0, 0, 0, T - 1], fill=line)
    return img


# ---------------------------------------------------------------- atlas

FRONT = {
    "terra": terra, "grama": grama, "argila": argila, "areia": areia, "cascalho": cascalho,
    "calcario": calcario, "xisto": xisto, "rocha_base": rocha_base,
    "tronco": tronco, "folhas": folhas, "agua": agua, "agua_topo": lambda r: agua(r, True),
}
ORES = {
    "malaquita": malaquita, "limonita": limonita, "carvao_mineral": carvao, "hematita": hematita,
    "quartzo": quartzo, "acantita": acantita, "silex": silex,
}
NO_WALL = {"tronco", "folhas", "agua", "agua_topo"}


def build_tiles() -> dict:
    atlas = Image.new("RGBA", (T * VARIANTS * 2, T * len(FRONT)), (0, 0, 0, 0))
    mapping = {}
    for row, (name, painter) in enumerate(FRONT.items()):
        for v in range(VARIANTS):
            rng = random.Random(f"{name}-{v}")
            tile = painter(rng)
            atlas.paste(tile, (v * T, row * T))
            if name not in NO_WALL:
                atlas.paste(darker(tile, 0.42), ((VARIANTS + v) * T, row * T))
        mapping[name] = {"linha": row, "parede": name not in NO_WALL}
    ores = Image.new("RGBA", (T * VARIANTS, T * len(ORES)), (0, 0, 0, 0))
    ore_map = {}
    for row, (name, painter) in enumerate(ORES.items()):
        for v in range(VARIANTS):
            ores.paste(painter(random.Random(f"{name}-{v}")), (v * T, row * T))
        ore_map[name] = {"linha": row}
    edges = Image.new("RGBA", (T * 16, T), (0, 0, 0, 0))
    for mask in range(16):
        edges.paste(borda(mask), (mask * T, 0))

    out = ART / "tiles"
    out.mkdir(parents=True, exist_ok=True)
    atlas.save(out / "tiles.png")
    ores.save(out / "minerios.png")
    edges.save(out / "bordas.png")
    meta = {
        "tamanho": T,
        "variacoes": VARIANTS,
        "coluna_parede": VARIANTS,
        "tiles": mapping,
        "minerios": ore_map,
        "observacao": "Gerado por tools/art/gerar_arte.py. Minérios são desenhados por cima da rocha da camada.",
    }
    (out / "tiles.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return {"atlas": atlas, "ores": ores, "edges": edges}


# ---------------------------------------------------------------- personagem

PW, PH = 16, 32
ANIMS = [("parado", 4), ("andar", 8), ("pular", 2)]
SKIN = ("94744f", "b8956a")
TUNIC = ("5e161a", "8a2224", "b8322a")
PANTS = ("2b231d", "3d3128")
BOOT = ("0f0d0c", "1b1714")
HAIR = ("1b1714", "2b231d", "57432f")
OUTLINE = "1b1714"
PARTS = ["braco_tras", "pernas", "tronco", "cabeca", "cabelo", "braco_frente"]


def pose(anim: str, frame: int) -> dict:
    """Posição dos membros por quadro. Valores em pixels, personagem virado para a direita."""
    p = {"bob": 0, "front_leg": 0, "back_leg": 0, "front_arm": 0, "back_arm": 0, "lift_f": 0, "lift_b": 0, "arms_up": 0}
    if anim == "parado":
        p["bob"] = (0, 0, 1, 1)[frame]
    elif anim == "andar":
        swing = (0, 2, 3, 2, 0, -2, -3, -2)[frame]
        p.update(front_leg=swing, back_leg=-swing, front_arm=-swing // 2 * 1, back_arm=swing // 2)
        p["bob"] = (0, 1, 0, 0, 0, 1, 0, 0)[frame]
        p["lift_f"] = 1 if swing > 1 else 0
        p["lift_b"] = 1 if swing < -1 else 0
    elif anim == "pular":
        if frame == 0:  # subindo: pernas recolhidas, braços para cima
            p.update(front_leg=2, back_leg=-1, lift_f=3, lift_b=1, arms_up=1)
        else:  # caindo: pernas estendidas, braços abertos
            p.update(front_leg=1, back_leg=-2, arms_up=-1)
    return p


def leg(d: ImageDraw.ImageDraw, ox: int, hip_x: int, foot_dx: int, lift: int, back: bool) -> None:
    pants = PANTS[0] if back else PANTS[1]
    hip_y, foot_y = 21, 31 - lift
    for y in range(hip_y, foot_y - 1):
        t = (y - hip_y) / max(1, (foot_y - hip_y))
        x = ox + hip_x + round(foot_dx * t)
        d.rectangle([x, y, x + 2, y], fill=c(pants))
    fx = ox + hip_x + foot_dx
    d.rectangle([fx, foot_y - 2, fx + 3, foot_y], fill=c(BOOT[0] if back else BOOT[1]))
    d.point([fx + 3, foot_y - 2], fill=c(OUTLINE))


def arm(d: ImageDraw.ImageDraw, ox: int, sx: int, hand_dx: int, bob: int, up: int, back: bool) -> None:
    sleeve = TUNIC[0] if back else TUNIC[2]
    skin = SKIN[0] if back else SKIN[1]
    top = 12 + bob
    length = 7 if up == 0 else (5 if up > 0 else 6)
    for i in range(length):
        x = ox + sx + round(hand_dx * i / length) - (up if up > 0 else 0) * 0
        y = top + i - (2 * i // 3 if up > 0 else 0)
        d.rectangle([x, y, x + 1, y], fill=c(sleeve))
        if not back:
            d.point([x - 1, y], fill=c(TUNIC[0]))
    hx = ox + sx + hand_dx + (1 if up < 0 else 0)
    hy = top + length - (2 * length // 3 if up > 0 else 0)
    d.rectangle([hx, hy, hx + 1, hy + 1], fill=c(skin))


def draw_part(part: str, anim: str, frame: int) -> Image.Image:
    img = Image.new("RGBA", (PW, PH), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    p = pose(anim, frame)
    b = p["bob"]
    if part == "pernas":
        leg(d, 0, 5, p["back_leg"], p["lift_b"], True)
        leg(d, 0, 8, p["front_leg"], p["lift_f"], False)
    elif part == "tronco":
        top = 11 + b
        d.rectangle([5, top, 10, 21], fill=c(TUNIC[1]))
        d.line([5, top, 5, 21], fill=c(TUNIC[0]))
        d.line([10, top + 1, 10, 21], fill=c(TUNIC[2]))
        d.line([4, 21, 11, 21], fill=c(TUNIC[0]))  # barra da túnica
        d.line([5, 17 + b, 10, 17 + b], fill=c("57432f"))  # cinto
        d.point([9, 17 + b], fill=c("e2b33c"))  # fivela
        d.line([6, top, 9, top], fill=c(TUNIC[2]))  # gola
    elif part == "cabeca":
        top = 4 + b
        d.rectangle([5, top, 10, top + 6], fill=c(SKIN[1]))
        d.line([5, top + 6, 10, top + 6], fill=c(SKIN[0]))
        d.line([5, top, 5, top + 6], fill=c(SKIN[0]))
        d.point([9, top + 3], fill=c("0f0d0c"))  # olho
        d.point([11, top + 4], fill=c(SKIN[1]))  # nariz
    elif part == "cabelo":
        top = 3 + b
        d.rectangle([5, top, 10, top + 1], fill=c(HAIR[1]))
        d.rectangle([4, top + 1, 6, top + 5], fill=c(HAIR[1]))
        d.line([6, top, 10, top], fill=c(HAIR[2]))
        d.point([4, top + 5], fill=c(HAIR[0]))
    elif part == "braco_tras":
        arm(d, 0, 5, p["back_arm"], b, p["arms_up"], True)
    elif part == "braco_frente":
        arm(d, 0, 8, p["front_arm"], b, p["arms_up"], False)
    return img


def outline(img: Image.Image) -> Image.Image:
    """Contorno de 1 px na silhueta completa (cor da paleta, não preto puro)."""
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    src = img.load()
    dst = out.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3]:
                    dst[x, y] = c(OUTLINE)
                    break
    return out


def build_character() -> Image.Image:
    rows = len(ANIMS)
    cols = max(n for _, n in ANIMS)
    sheets = {part: Image.new("RGBA", (PW * cols, PH * rows), (0, 0, 0, 0)) for part in PARTS + ["contorno"]}
    composite = Image.new("RGBA", (PW * cols, PH * rows), (0, 0, 0, 0))
    for row, (anim, frames) in enumerate(ANIMS):
        for frame in range(frames):
            full = Image.new("RGBA", (PW, PH), (0, 0, 0, 0))
            for part in PARTS:
                piece = draw_part(part, anim, frame)
                sheets[part].paste(piece, (frame * PW, row * PH))
                full.alpha_composite(piece)
            line = outline(full)
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
        "observacao": "Partes empilhadas na ordem de 'partes' (de trás para frente). Armadura, ferramenta e efeito entram nas Ondas 3-5.",
    }
    (out / "personagem.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return composite


# ---------------------------------------------------------------- prancha e verificação

def check_palette(*images: Image.Image) -> None:
    allowed = set(PAL.values())
    for img in images:
        pixels = img.get_flattened_data() if hasattr(img, "get_flattened_data") else img.getdata()
        for r, g, b, a in pixels:
            if a and (r, g, b) not in allowed:
                raise SystemExit(f"cor fora da paleta encontrada: {(r, g, b)}")


def board(parts: dict, composite: Image.Image) -> None:
    scale = 3
    atlas, ores, edges = parts["atlas"], parts["ores"], parts["edges"]
    # Exemplo: minérios sobre suas rochas.
    hosts = {"malaquita": "calcario", "limonita": "terra", "carvao_mineral": "calcario", "hematita": "xisto",
             "quartzo": "xisto", "acantita": "xisto", "silex": "terra"}
    rows_front = list(FRONT)
    sample = Image.new("RGBA", (T * VARIANTS, T * len(ORES)), (0, 0, 0, 0))
    for row, name in enumerate(ORES):
        host_row = rows_front.index(hosts[name])
        for v in range(VARIANTS):
            sample.paste(atlas.crop((v * T, host_row * T, (v + 1) * T, (host_row + 1) * T)), (v * T, row * T))
        sample.alpha_composite(ores.crop((0, row * T, ores.width, (row + 1) * T)), (0, row * T))
    pad = 8
    width = (atlas.width + sample.width + composite.width) * scale + pad * 4
    height = max(atlas.height, sample.height, composite.height) * scale + pad * 2
    out = Image.new("RGBA", (width, height), c("1b1714"))
    x = pad
    for img in (atlas, sample, composite):
        out.alpha_composite(img.resize((img.width * scale, img.height * scale), Image.NEAREST), (x, pad))
        x += img.width * scale + pad
    (ROOT / "docs" / "img").mkdir(parents=True, exist_ok=True)
    out.save(ROOT / "docs" / "img" / "arte-base.png")


def main() -> None:
    parts = build_tiles()
    composite = build_character()
    check_palette(parts["atlas"], parts["ores"], composite)
    board(parts, composite)
    print(f"OK: {len(FRONT)} tiles, {len(ORES)} minérios, 16 bordas, personagem com {len(PARTS)} partes")


if __name__ == "__main__":
    main()
