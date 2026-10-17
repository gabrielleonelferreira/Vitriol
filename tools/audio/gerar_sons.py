#!/usr/bin/env python3
"""Sons do Vitriol gerados por código (síntese), como a arte: originais, coerentes e sem licença de terceiros.

Uso: python3 tools/audio/gerar_sons.py
Gera audio/*.wav (mono, 22.050 Hz, 16 bits) e audio/sons.json (nome -> arquivos e se é contínuo).
Rodar de novo gera os mesmos arquivos (sementes fixas).
"""

from __future__ import annotations

import json
import wave
from pathlib import Path

import numpy as np
from scipy import signal

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "audio"
RATE = 22050


# ================================================================ peças básicas


def t(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * RATE)) / RATE


def noise(seconds: float, rng: np.random.Generator) -> np.ndarray:
    return rng.uniform(-1.0, 1.0, int(seconds * RATE))


def brown(seconds: float, rng: np.random.Generator) -> np.ndarray:
    out = np.cumsum(rng.uniform(-1.0, 1.0, int(seconds * RATE)))
    out -= signal.lfilter([1.0], [1.0, -0.995], out) * 0.005  # tira a deriva
    out = signal.lfilter([1.0, -1.0], [1.0, -0.995], out)
    return out / (np.max(np.abs(out)) + 1e-9)


def lowpass(x: np.ndarray, hz: float, order: int = 2) -> np.ndarray:
    b, a = signal.butter(order, hz / (RATE / 2), "low")
    return signal.lfilter(b, a, x)


def highpass(x: np.ndarray, hz: float, order: int = 2) -> np.ndarray:
    b, a = signal.butter(order, hz / (RATE / 2), "high")
    return signal.lfilter(b, a, x)


def bandpass(x: np.ndarray, lo: float, hi: float, order: int = 2) -> np.ndarray:
    b, a = signal.butter(order, [lo / (RATE / 2), hi / (RATE / 2)], "band")
    return signal.lfilter(b, a, x)


def decay(seconds: float, rate: float, attack: float = 0.002) -> np.ndarray:
    tt = t(seconds)
    env = np.exp(-tt * rate)
    a = int(attack * RATE)
    if a > 0:
        env[:a] *= np.linspace(0.0, 1.0, a)
    return env


def tone(freq_from: float, freq_to: float, seconds: float, harmonics=(1.0,)) -> np.ndarray:
    tt = t(seconds)
    freq = np.linspace(freq_from, freq_to, tt.size)
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    out = np.zeros_like(tt)
    for n, amp in enumerate(harmonics, start=1):
        out += amp * np.sin(phase * n)
    return out


def bell(freq: float, seconds: float) -> np.ndarray:
    """Sino suave: parciais levemente inarmônicos, os agudos somem antes."""
    tt = t(seconds)
    out = np.zeros_like(tt)
    for ratio, amp, rate in ((1.0, 1.0, 5.0), (2.0, 0.4, 8.0), (2.76, 0.25, 12.0), (5.4, 0.08, 20.0)):
        out += amp * np.sin(2 * np.pi * freq * ratio * tt) * np.exp(-tt * rate)
    att = int(0.004 * RATE)
    out[:att] *= np.linspace(0, 1, att)
    return out


def mix(length: float, *parts: tuple[float, np.ndarray]) -> np.ndarray:
    out = np.zeros(int(length * RATE))
    for start, part in parts:
        i = int(start * RATE)
        end = min(out.size, i + part.size)
        out[i:end] += part[: end - i]
    return out


def finish(x: np.ndarray, peak: float = 0.8) -> np.ndarray:
    x = x - np.mean(x)
    fade = min(int(0.006 * RATE), x.size // 4)
    if fade:
        x[-fade:] *= np.linspace(1, 0, fade)
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def loopable(x: np.ndarray, overlap: float = 0.3) -> np.ndarray:
    """Emenda o fim no começo com cruzamento, para tocar em loop sem estalo."""
    n = int(overlap * RATE)
    head, body = x[:n], x[n:]
    ramp = np.linspace(0, 1, n)
    body[-n:] = body[-n:] * (1 - ramp) + head * ramp
    return body


# ================================================================ sons


def hit_stone(rng):
    click = highpass(noise(0.03, rng), 2500) * decay(0.03, 160)
    ping = tone(1100 + rng.uniform(-120, 120), 700, 0.06, (1.0, 0.3)) * decay(0.06, 70)
    return finish(mix(0.07, (0, click), (0, ping * 0.5)), 0.7)


def hit_dirt(rng):
    thud = lowpass(noise(0.08, rng), 700) * decay(0.08, 45)
    body = tone(150 + rng.uniform(-20, 20), 90, 0.07) * decay(0.07, 55)
    return finish(mix(0.09, (0, thud), (0, body * 0.6)), 0.65)


def hit_wood(rng):
    f = 300 + rng.uniform(-40, 40)
    knock = tone(f, f * 0.9, 0.09, (1.0, 0.5, 0.2)) * decay(0.09, 50)
    tap = bandpass(noise(0.02, rng), 1500, 4000) * decay(0.02, 200)
    return finish(mix(0.1, (0, knock), (0, tap * 0.4)), 0.7)


def hit_leaves(rng):
    rustle = bandpass(noise(0.14, rng), 2000, 7000) * decay(0.14, 18, 0.02)
    rustle *= 0.6 + 0.4 * np.abs(np.sin(t(0.14) * 90))
    return finish(rustle, 0.45)


def break_stone(rng):
    parts = [(rng.uniform(0, 0.2), hit_stone(rng) * rng.uniform(0.4, 1.0)) for _ in range(6)]
    rumble = lowpass(brown(0.3, rng), 300) * decay(0.3, 9)
    return finish(mix(0.32, (0, rumble * 0.8), *parts), 0.85)


def break_dirt(rng):
    parts = [(rng.uniform(0, 0.12), hit_dirt(rng) * rng.uniform(0.4, 1.0)) for _ in range(4)]
    crumble = lowpass(noise(0.25, rng), 1200) * decay(0.25, 14)
    return finish(mix(0.27, (0, crumble * 0.6), *parts), 0.8)


def break_wood(rng):
    crack = highpass(noise(0.05, rng), 1800) * decay(0.05, 70)
    creak = tone(180, 120, 0.25, (1.0, 0.6, 0.3)) * decay(0.25, 10, 0.03) * 0.5
    return finish(mix(0.3, (0, crack), (0.02, creak), (0.05, hit_wood(rng) * 0.6)), 0.85)


def place(rng):
    thump = lowpass(noise(0.05, rng), 900) * decay(0.05, 70)
    body = tone(220, 160, 0.05) * decay(0.05, 80)
    return finish(mix(0.06, (0, thump), (0, body * 0.5)), 0.6)


def step_grass(rng):
    return finish(bandpass(noise(0.07, rng), 800, 4500) * decay(0.07, 55, 0.008), 0.35)


def step_stone(rng):
    tap = highpass(noise(0.03, rng), 1800) * decay(0.03, 120)
    return finish(mix(0.04, (0, tap), (0, tone(600, 500, 0.03) * decay(0.03, 120) * 0.3)), 0.35)


def step_wood(rng):
    return finish(tone(260 + rng.uniform(-30, 30), 230, 0.06, (1.0, 0.4)) * decay(0.06, 70), 0.35)


def jump(rng):
    whoosh = bandpass(noise(0.14, rng), 400, 2200) * decay(0.14, 20, 0.03)
    return finish(whoosh, 0.25)


def wind_jump(rng):
    tt = t(0.35)
    air = noise(0.35, rng)
    air = bandpass(air, 600, 5000) * np.sin(np.pi * tt / 0.35) ** 2
    shimmer = sum(bell(f, 0.35) for f in (1320, 1760)) * 0.15
    return finish(air + shimmer, 0.5)


def thunder(rng):
    crack = highpass(noise(0.12, rng), 1200) * decay(0.12, 25, 0.001)
    rumble = lowpass(brown(2.6, rng), 140, 3)
    tt = t(2.6)
    rumble *= np.exp(-tt * 1.3) * (0.6 + 0.4 * np.sin(tt * 5.0 + rng.uniform(0, 3)) ** 2)
    rumble *= np.clip(tt / 0.08, 0, 1)
    rumble /= np.max(np.abs(rumble)) + 1e-9
    crack /= np.max(np.abs(crack)) + 1e-9
    return finish(mix(2.6, (0, crack * 0.8), (0.03, rumble)), 0.9)


def cast_bolt(rng):
    crack = highpass(noise(0.1, rng), 1500) * decay(0.1, 30, 0.001)
    zap = tone(2400, 300, 0.25, (1.0, 0.5)) * decay(0.25, 14) * 0.4
    boom = lowpass(brown(0.9, rng), 160, 3) * decay(0.9, 4.5)
    return finish(mix(0.95, (0, crack), (0, zap), (0.02, boom)), 0.9)


def rain(rng):
    length = 4.3
    hiss = lowpass(highpass(noise(length, rng), 500), 4500) * 0.35
    drops = np.zeros(int(length * RATE))
    for _ in range(260):
        i = rng.integers(0, drops.size - 400)
        d = bandpass(noise(0.015, rng), 2000, 8000) * decay(0.015, 250) * rng.uniform(0.2, 0.7)
        drops[i : i + d.size] += d
    return finish(loopable(hiss + drops), 0.5)


def fire(rng):
    length = 3.3
    roar = lowpass(brown(length, rng), 500, 3) * 0.8
    crackle = np.zeros(int(length * RATE))
    for _ in range(45):
        i = rng.integers(0, crackle.size - 300)
        c = highpass(noise(0.008, rng), 2500) * decay(0.008, 500) * rng.uniform(0.3, 1.0)
        crackle[i : i + c.size] += c
    return finish(loopable(roar + crackle * 0.9), 0.5)


def ready(rng):
    return finish(mix(0.5, (0, bell(659.3, 0.4)), (0.11, bell(880.0, 0.39))), 0.5)


def discovery(rng):
    notes = (523.3, 659.3, 784.0, 1046.5)
    return finish(mix(0.9, *[(i * 0.09, bell(f, 0.6)) for i, f in enumerate(notes)]), 0.55)


def level_up(rng):
    notes = (392.0, 523.3, 659.3, 784.0, 1046.5, 1318.5)
    shimmer = bandpass(noise(1.1, rng), 4000, 9000) * decay(1.1, 3, 0.2) * 0.15
    return finish(mix(1.2, (0.2, shimmer), *[(i * 0.07, bell(f, 0.7)) for i, f in enumerate(notes)]), 0.6)


def click(rng):
    return finish(tone(1800, 1500, 0.02) * decay(0.02, 250), 0.3)


def door_open(rng):
    creak = tone(330, 260, 0.22, (1.0, 0.7, 0.4, 0.2)) * decay(0.22, 8, 0.04)
    creak *= 0.7 + 0.3 * np.sin(t(0.22) * 140)
    return finish(mix(0.24, (0, creak * 0.5), (0.18, hit_wood(rng) * 0.4)), 0.45)


def door_close(rng):
    return finish(mix(0.15, (0, hit_wood(rng)), (0.03, place(rng) * 0.5)), 0.5)


def fizzle(rng):
    tt = t(0.4)
    fizz = noise(0.4, rng)
    cutoff = np.linspace(5000, 600, tt.size)
    out = np.zeros_like(fizz)
    y = 0.0
    for i in range(fizz.size):  # passa-baixa que vai fechando
        k = cutoff[i] / RATE * 2 * np.pi
        y += (fizz[i] - y) * min(k, 1.0)
        out[i] = y
    out *= decay(0.4, 6, 0.01)
    blip = tone(220, 140, 0.15) * decay(0.15, 20) * 0.5
    return finish(mix(0.42, (0, out), (0.05, blip)), 0.45)


def ladder(rng):
    return finish(tone(420 + rng.uniform(-40, 40), 380, 0.04, (1.0, 0.3)) * decay(0.04, 90), 0.3)


SOUNDS = {
    "minerar_pedra": (hit_stone, 3),
    "minerar_terra": (hit_dirt, 3),
    "minerar_madeira": (hit_wood, 3),
    "minerar_folhas": (hit_leaves, 2),
    "quebrar_pedra": (break_stone, 2),
    "quebrar_terra": (break_dirt, 2),
    "quebrar_madeira": (break_wood, 2),
    "colocar": (place, 2),
    "passo_grama": (step_grass, 3),
    "passo_pedra": (step_stone, 3),
    "passo_madeira": (step_wood, 2),
    "pulo": (jump, 1),
    "salto_vento": (wind_jump, 1),
    "trovao": (thunder, 2),
    "raio_invocado": (cast_bolt, 1),
    "chuva": (rain, 1),
    "fogo": (fire, 1),
    "pronto": (ready, 1),
    "descoberta": (discovery, 1),
    "nivel": (level_up, 1),
    "clique": (click, 1),
    "porta_abre": (door_open, 1),
    "porta_fecha": (door_close, 1),
    "falhou": (fizzle, 1),
    "escada": (ladder, 2),
}
LOOPS = {"chuva", "fogo"}


def write_wav(path: Path, x: np.ndarray) -> None:
    data = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for name, (painter, variants) in SOUNDS.items():
        files = []
        for v in range(variants):
            rng = np.random.default_rng(sum(map(ord, name)) * 31 + v)
            sound = painter(rng)
            file = f"{name}_{v + 1}.wav" if variants > 1 else f"{name}.wav"
            write_wav(OUT / file, sound)
            files.append(file)
        manifest[name] = {"arquivos": files, "loop": name in LOOPS}
    (OUT / "sons.json").write_text(json.dumps({"sons": manifest}, ensure_ascii=False, indent=2) + "\n",
                                   encoding="utf-8")
    total = sum(len(v["arquivos"]) for v in manifest.values())
    print(f"OK: {len(manifest)} sons, {total} arquivos em audio/")


if __name__ == "__main__":
    main()
