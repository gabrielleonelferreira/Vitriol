#!/usr/bin/env python3
"""Confere se todo caminho res:// citado no projeto aponta para um arquivo que existe.

Uso (na raiz do repositório):
    python3 tools/check_project.py

Cobre project.godot, cenas (.tscn), recursos (.tres) e scripts (.gd: preload/load).
Útil quando não há um Godot à mão; não substitui abrir o projeto no editor.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RES = re.compile(r'res://([^"\')\s]+)')
SKIP_DIRS = {".godot", ".git"}


def main() -> int:
    files = [ROOT / "project.godot"]
    for pattern in ("*.tscn", "*.tres", "*.gd"):
        files += [p for p in ROOT.rglob(pattern) if not SKIP_DIRS & set(p.parts)]
    missing = []
    checked = 0
    for path in files:
        for match in RES.finditer(path.read_text(encoding="utf-8")):
            checked += 1
            target = ROOT / match.group(1)
            if not target.exists():
                missing.append(f"{path.relative_to(ROOT)}: res://{match.group(1)}")
    if missing:
        print("Caminhos inexistentes:")
        for item in missing:
            print("  - " + item)
        return 1
    print(f"OK: {checked} caminhos res:// conferidos em {len(files)} arquivos")
    return 0


if __name__ == "__main__":
    sys.exit(main())
