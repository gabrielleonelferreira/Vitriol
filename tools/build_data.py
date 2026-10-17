#!/usr/bin/env python3
"""Converte o conteúdo do jogo (CSV) em JSON e valida tudo.

Uso (na raiz do repositório):
    pip install jsonschema
    python3 tools/build_data.py

Lê    data/content/materiais.csv, itens.csv, receitas.csv, geracao.csv
Gera  data/generated/materiais.json, itens.json, receitas.json, geracao.json
Valida contra data/schema/*.schema.json e confere:
  - ids únicos entre materiais e itens
  - referências (entradas, saídas, estações, ferramentas, material base)
  - temperatura da receita dentro do limite da estação
  - regras de desbloqueio
  - regras de geração do mundo (material é bloco, camada coerente, uma rocha por camada)
  - progressão: tudo é alcançável partindo de mãos vazias

Sai com código 1 se houver erro. Avisos não impedem a geração.
"""

from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator
from referencing import Registry, Resource

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "data" / "content"
GENERATED = ROOT / "data" / "generated"
SCHEMA = ROOT / "data" / "schema"

MAOS = "mao"  # estação implícita: fazer à mão, sem bancada
PODER_MAOS = 1.0



class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def error(self, msg: str) -> None:
        self.errors.append(msg)

    def warn(self, msg: str) -> None:
        self.warnings.append(msg)


# ---------- leitura do CSV ----------

def _blank(value: str | None) -> bool:
    return value is None or value.strip() == ""


def _num(value: str) -> float | int | None:
    if _blank(value):
        return None
    number = float(value.replace(",", "."))
    return int(number) if number.is_integer() else number


def _int(value: str) -> int | None:
    number = _num(value)
    return None if number is None else int(number)


def _text(value: str | None) -> str:
    return "" if value is None else value.strip()


def _opt_id(value: str) -> str | None:
    return None if _blank(value) else value.strip()


def _quantidades(value: str) -> list[dict]:
    """'malaquita:2;carvao_vegetal:1' -> [{'id': 'malaquita', 'qtd': 2}, ...]"""
    result = []
    for part in _text(value).split(";"):
        if not part.strip():
            continue
        item_id, _, qtd = part.partition(":")
        result.append({"id": item_id.strip(), "qtd": int(qtd) if qtd.strip() else 1})
    return result


def _requer(value: str) -> list[dict]:
    """'evento:tempestade|magia:tempestaria' -> alternativas"""
    result = []
    for part in _text(value).split("|"):
        if not part.strip():
            continue
        tipo, _, ident = part.partition(":")
        result.append({"tipo": tipo.strip(), "id": ident.strip()})
    return result


def _read_csv(name: str) -> list[dict]:
    with open(CONTENT / name, newline="", encoding="utf-8") as handle:
        return [row for row in csv.DictReader(handle) if any(_text(v) for v in row.values())]


def load_materiais() -> list[dict]:
    rows = []
    for r in _read_csv("materiais.csv"):
        rows.append({
            "id": _text(r["id"]),
            "nome": _text(r["nome"]),
            "categoria": _text(r["categoria"]),
            "tier": _text(r["tier"]),
            "dureza_bloco": _num(r["dureza_bloco"]),
            "dureza_mohs": _num(r["dureza_mohs"]),
            "densidade_g_cm3": _num(r["densidade_g_cm3"]),
            "ponto_fusao_c": _num(r["ponto_fusao_c"]),
            "condutividade": _int(r["condutividade"]) or 0,
            "afinidade_arcana": _int(r["afinidade_arcana"]) or 0,
            "escola_afim": _opt_id(r["escola_afim"]),
            "fonte": _text(r["fonte"]),
            "fonte_detalhe": _text(r["fonte_detalhe"]),
            "ferramenta_coleta": _opt_id(r["ferramenta_coleta"]),
            "camadas": [int(c) for c in _text(r["camadas"]).split(";") if c.strip()],
            "maestria": _text(r["maestria"]),
            "xp_descoberta": _int(r["xp_descoberta"]) or 0,
            "base_real": _text(r["base_real"]),
            "descricao": _text(r["descricao"]),
            "luz_raio": _num(r.get("luz_raio", "")),
            "luz_cor": _opt_id(r.get("luz_cor", "")),
        })
    return rows


def load_itens() -> list[dict]:
    rows = []
    for r in _read_csv("itens.csv"):
        rows.append({
            "id": _text(r["id"]),
            "nome": _text(r["nome"]),
            "tipo": _text(r["tipo"]),
            "material_base": _opt_id(r["material_base"]),
            "poder_mineracao": _num(r["poder_mineracao"]),
            "durabilidade": _int(r["durabilidade"]),
            "temperatura_max_c": _num(r["temperatura_max_c"]),
            "descricao": _text(r["descricao"]),
            "luz_raio": _num(r.get("luz_raio", "")),
            "luz_cor": _opt_id(r.get("luz_cor", "")),
            "forma": _opt_id(r.get("forma", "")),
        })
    return rows


def load_geracao() -> list[dict]:
    rows = []
    for r in _read_csv("geracao.csv"):
        rows.append({
            "material": _text(r["material"]),
            "camada": _int(r["camada"]),
            "forma": _text(r["forma"]),
            "frequencia": _num(r["frequencia"]) or 0,
            "tamanho_min": _int(r["tamanho_min"]),
            "tamanho_max": _int(r["tamanho_max"]),
            "observacao": _text(r.get("observacao")),
        })
    return rows


def rocks_by_layer(geracao: list[dict]) -> dict[int, str]:
    """Rocha principal de cada camada, lida das regras de geração (forma 'rocha')."""
    return {g["camada"]: g["material"] for g in geracao if g["forma"] == "rocha"}


def load_receitas() -> list[dict]:
    rows = []
    for r in _read_csv("receitas.csv"):
        rows.append({
            "id": _text(r["id"]),
            "nome": _text(r["nome"]),
            "estacao": _text(r["estacao"]),
            "processo": _text(r["processo"]),
            "entradas": _quantidades(r["entradas"]),
            "saidas": _quantidades(r["saidas"]),
            "temperatura_min_c": _num(r["temperatura_min_c"]),
            "requer": _requer(r["requer"]),
            "tempo_s": _num(r["tempo_s"]),
            "maestria": _text(r["maestria"]),
            "xp": _int(r["xp"]) or 0,
            "desbloqueio": _text(r["desbloqueio"]),
            "nivel_maestria": _int(r["nivel_maestria"]),
            "base_real": _text(r["base_real"]),
        })
    return rows


# ---------- validação ----------

def _validators() -> dict[str, Draft202012Validator]:
    schemas = {p.name: json.loads(p.read_text(encoding="utf-8")) for p in SCHEMA.glob("*.schema.json")}
    registry = Registry().with_resources(
        (s["$id"], Resource.from_contents(s)) for s in schemas.values()
    )
    return {
        name: Draft202012Validator(schemas[f"{name}.schema.json"], registry=registry)
        for name in ("material", "item", "receita", "geracao")
    }


def validate_schema(kind: str, rows: list[dict], validator: Draft202012Validator, report: Report) -> None:
    for row in rows:
        for err in validator.iter_errors(row):
            path = ".".join(str(p) for p in err.absolute_path) or "(registro)"
            report.error(f"{kind} '{row.get('id')}': {path}: {err.message}")


def validate_rules(materiais: list[dict], itens: list[dict], receitas: list[dict], report: Report) -> None:
    mat = {m["id"]: m for m in materiais}
    itm = {i["id"]: i for i in itens}

    ids = [m["id"] for m in materiais] + [i["id"] for i in itens]
    for dup in sorted({x for x in ids if ids.count(x) > 1}):
        report.error(f"id repetido entre materiais e itens: '{dup}'")
    rec_ids = [r["id"] for r in receitas]
    for dup in sorted({x for x in rec_ids if rec_ids.count(x) > 1}):
        report.error(f"id de receita repetido: '{dup}'")

    known = set(mat) | set(itm)

    for m in materiais:
        tool = m["ferramenta_coleta"]
        if tool and (tool not in itm or itm[tool]["tipo"] != "ferramenta"):
            report.error(f"material '{m['id']}': ferramenta_coleta '{tool}' não é uma ferramenta")
        if m["fonte"] in ("mineracao",) and m["dureza_bloco"] is None:
            report.error(f"material '{m['id']}': fonte mineracao exige dureza_bloco")
        if m["escola_afim"] and m["afinidade_arcana"] == 0:
            report.warn(f"material '{m['id']}': tem escola_afim mas afinidade_arcana 0")

    for i in itens:
        if i["material_base"] and i["material_base"] not in mat:
            report.error(f"item '{i['id']}': material_base '{i['material_base']}' não existe")
        if i.get("forma") and i["tipo"] != "objeto":
            report.error(f"item '{i['id']}': forma '{i['forma']}' só vale para objetos")
        if i["tipo"] == "ferramenta" and i["durabilidade"] is None:
            report.warn(f"ferramenta '{i['id']}' sem durabilidade")

    produced = set()
    for r in receitas:
        rid = r["id"]
        station = itm.get(r["estacao"])
        if station is None or station["tipo"] not in ("estacao", "fenomeno"):
            report.error(f"receita '{rid}': estação '{r['estacao']}' não existe ou não é estação")
        for part in r["entradas"] + r["saidas"]:
            if part["id"] not in known:
                report.error(f"receita '{rid}': '{part['id']}' não existe")
        for part in r["saidas"]:
            produced.add(part["id"])
        tmin, tmax = r["temperatura_min_c"], station and station["temperatura_max_c"]
        if tmin is not None and tmax is not None and tmin > tmax:
            report.error(f"receita '{rid}': precisa de {tmin} °C, mas '{r['estacao']}' chega a {tmax} °C")
        if tmin is not None and station is not None and tmax is None:
            report.error(f"receita '{rid}': exige temperatura, mas '{r['estacao']}' não aquece")
        if r["desbloqueio"] == "xp" and not r["nivel_maestria"]:
            report.error(f"receita '{rid}': desbloqueio por xp exige nivel_maestria")
        if r["desbloqueio"] != "xp" and r["nivel_maestria"]:
            report.warn(f"receita '{rid}': nivel_maestria ignorado (desbloqueio '{r['desbloqueio']}')")

    for m in materiais:
        if m["fonte"] == "processo" and m["id"] not in produced:
            report.error(f"material '{m['id']}': fonte 'processo', mas nenhuma receita o produz")

    used = {p["id"] for r in receitas for p in r["entradas"]}
    for m in materiais:
        desperta_escola = m["tier"] == "mitico" and m["escola_afim"]
        if m["id"] not in used and not desperta_escola:
            report.warn(f"material '{m['id']}' ainda não é usado em nenhuma receita")


def validate_generation(materiais: list[dict], geracao: list[dict], report: Report) -> None:
    mat = {m["id"]: m for m in materiais}
    rocks: dict[int, list[str]] = {}
    for g in geracao:
        label = f"geração '{g['material']}' camada {g['camada']} ({g['forma']})"
        m = mat.get(g["material"])
        if m is None:
            report.error(f"{label}: material não existe")
            continue
        if m["dureza_bloco"] is None and m["categoria"] != "liquido":
            report.error(f"{label}: material não é bloco (dureza_bloco vazia)")
        if g["camada"] not in m["camadas"]:
            report.error(f"{label}: a camada não está nas camadas do material ({m['camadas']})")
        if g["tamanho_max"] < g["tamanho_min"]:
            report.error(f"{label}: tamanho_max menor que tamanho_min")
        if g["forma"] == "rocha":
            rocks.setdefault(g["camada"], []).append(g["material"])
    for camada, ids in sorted(rocks.items()):
        if len(ids) > 1:
            report.error(f"geração: camada {camada} tem mais de uma rocha principal: {ids}")
    camadas = sorted(rocks)
    if camadas != list(range(1, len(camadas) + 1)):
        report.error(f"geração: as camadas com rocha principal precisam ser contínuas a partir de 1 (tem {camadas})")
    placed = {g["material"] for g in geracao}
    for m in materiais:
        if m["fonte"] == "mineracao" and m["id"] not in placed:
            report.warn(f"material '{m['id']}' tem fonte mineracao mas nenhuma regra de geração")


def simulate_progression(materiais: list[dict], itens: list[dict], receitas: list[dict], geracao: list[dict], report: Report) -> list[str]:
    """Parte de mãos vazias e vê até onde o jogador chega. Devolve as etapas em texto."""
    mat = {m["id"]: m for m in materiais}
    itm = {i["id"]: i for i in itens}
    fenomenos = {i["id"] for i in itens if i["tipo"] == "fenomeno"}
    have: set[str] = {MAOS} | fenomenos
    power = PODER_MAOS
    steps: list[str] = []

    ROCHA_DAS_CAMADAS = rocks_by_layer(geracao)
    for camada, rocha in ROCHA_DAS_CAMADAS.items():
        if rocha not in mat or mat[rocha]["dureza_bloco"] is None:
            report.error(f"progressão: rocha principal da camada {camada} ('{rocha}') não existe ou não é bloco")
            return steps

    def layer_reachable(camadas: list[int]) -> bool:
        if not camadas:
            return True
        target = min(camadas)
        return all(
            mat[ROCHA_DAS_CAMADAS[c]]["dureza_bloco"] <= power
            for c in ROCHA_DAS_CAMADAS
            if c <= target
        )

    def requirement_ok(r: dict) -> bool:
        if not r["requer"]:
            return True
        for alt in r["requer"]:
            if alt["tipo"] == "evento":
                return True  # eventos acontecem no mundo
            if alt["tipo"] == "magia":
                awakened = any(
                    m["id"] in have and m["tier"] == "mitico" and m["escola_afim"] == alt["id"]
                    for m in materiais
                )
                if awakened:
                    return True
        return False

    changed = True
    rodada = 0
    while changed:
        changed = False
        rodada += 1
        novos: list[str] = []
        for m in materiais:
            if m["id"] in have or m["fonte"] == "processo":
                continue
            tool = m["ferramenta_coleta"]
            if tool and tool not in have:
                continue
            if m["dureza_bloco"] is not None and m["dureza_bloco"] > power:
                continue
            if not layer_reachable(m["camadas"]):
                continue
            novos.append(m["id"])
        for r in receitas:
            if r["estacao"] not in have:
                continue
            if not all(p["id"] in have for p in r["entradas"]):
                continue
            if not requirement_ok(r):
                continue
            novos.extend(p["id"] for p in r["saidas"] if p["id"] not in have)
        novos = sorted(set(novos) - have)
        if novos:
            have.update(novos)
            changed = True
            new_power = max([PODER_MAOS] + [itm[i]["poder_mineracao"] or 0 for i in have if i in itm])
            power_note = f" (poder de mineração agora {new_power:g})" if new_power > power else ""
            power = new_power
            steps.append(f"rodada {rodada}: {', '.join(novos)}{power_note}")

    for ident in sorted((set(mat) | set(itm)) - have - {MAOS}):
        report.error(f"progressão: '{ident}' é inalcançável partindo de mãos vazias")
    return steps


def main() -> int:
    report = Report()
    materiais, itens, receitas = load_materiais(), load_itens(), load_receitas()
    geracao = load_geracao()
    validators = _validators()
    validate_schema("material", materiais, validators["material"], report)
    validate_schema("item", itens, validators["item"], report)
    validate_schema("receita", receitas, validators["receita"], report)
    validate_schema("geracao", geracao, validators["geracao"], report)
    validate_rules(materiais, itens, receitas, report)
    validate_generation(materiais, geracao, report)
    steps = simulate_progression(materiais, itens, receitas, geracao, report)

    print(f"{len(materiais)} materiais, {len(itens)} itens, {len(receitas)} receitas, {len(geracao)} regras de geração")
    print("\nProgressão a partir de mãos vazias:")
    for step in steps:
        print("  " + step)
    if report.warnings:
        print(f"\n{len(report.warnings)} aviso(s):")
        for w in report.warnings:
            print("  - " + w)
    if report.errors:
        print(f"\n{len(report.errors)} erro(s):")
        for e in report.errors:
            print("  - " + e)
        print("\nNada foi gerado.")
        return 1

    GENERATED.mkdir(parents=True, exist_ok=True)
    for name, rows in (("materiais", materiais), ("itens", itens), ("receitas", receitas), ("geracao", geracao)):
        payload = {"versao": 1, name: rows}
        (GENERATED / f"{name}.json").write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    print("\nOK: dados válidos, JSON gerado em data/generated/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
