# Vitriol — Status

## Onda atual

Onda 2 — Esqueleto técnico: **em andamento**. Onda 1 concluída (tag `onda-1`).

## Tarefas da onda

- [x] 1A Motor, repositório e arquitetura base — Godot 4, cliente + servidor local, testes de fumaça
- [x] 1B Esquema de dados — JSON Schema em `data/schema/`, validador `tools/build_data.py`
- [x] 1C Conteúdo do MVP — 34 materiais, 14 itens, 31 receitas em `data/content/`
- [x] 1D Guia de arte — `docs/guia-de-arte.md`, paleta em `art/paleta/`
- [x] 1E Busca de marca — `docs/marca.md` (busca oficial no INPI fica com o Gabriel)

## Portão da Onda 1

- [x] Esquema e conteúdo no repositório; `tools/build_data.py` passa sem erros
- [x] Todo o GDScript passa no analisador e no linter (gdtoolkit 4.5)
- [x] Todos os caminhos `res://` existem (`tools/check_project.py`)
- [x] Projeto abre no Godot 4.7.2 (PC do Gabriel) e a tela mostra "servidor local conectado"
- [x] `tests/run_tests.gd` passa no Godot 4.7.2 headless
- [x] Tag `onda-1`

## Decisões tomadas

- Motor: Godot 4.7+, renderizador Compatibility (roda em PCs mais fracos e suporta luz 2D)
- Resolução interna 640 × 360, escala inteira, filtro nearest
- Tile 16 × 16 px; personagem 16 × 32 px em 8 camadas
- Solo roda como cliente + servidor local; comandos e eventos em `core/shared/`
- Conteúdo em CSV → validado → JSON em `data/generated/` (versionado, o jogo lê o JSON)
- `data/content`, `data/schema`, `docs` e `tools` têm `.gdignore`: o Godot não importa essas pastas
  (ele trataria os CSV como tradução)
- Arquivos `.uid` e `.import` vão para o Git (recomendação do Godot 4.4+)
- Mineração: `dureza_bloco` (esforço) separada de `dureza_mohs` (real); picaretas têm
  `poder_mineracao` e `durabilidade`. Sílex e cobre têm o mesmo poder (4); o cobre dura mais
- Rocha principal por camada: Solo = terra, Sedimentar = calcário (3), Metamórfica = xisto (5)
- Primeira escola do MVP: Tempestária; a Pena de Ave-Trovão cai em tempestades (fonte provisória)

## Pendências e observações

- Balanceamento (Onda 5): a simulação mostra que a picareta de ferro (limonita da camada Solo) pode
  chegar antes da de bronze. Historicamente o bronze veio antes; dá para segurar o ferro pelo nível de
  maestria exigido em `reduzir_limonita`
- Materiais ainda sem uso em receita (normal no MVP): terra, xisto, quartzo, prata, ouro, vidro de
  tempestade
- Repositório remoto: definir onde fica (GitHub) para salvar entre sessões

## Próxima onda

Onda 2 — Esqueleto técnico, 4 tarefas em paralelo:

- 2A Mundo em tiles e geração (pasta `world/`)
- 2B Personagem: movimento, pulo, física, câmera (pasta `player/`)
- 2C Carregador de dados: lê `data/generated/*.json` (pasta `data_loader/`)
- 2D Arte base: tiles das 3 camadas e personagem em partes (pasta `art/`)

## Última sessão

16/10/2026 — Onda 1 inteira feita em uma sessão. O próximo passo é abrir o projeto no Godot, rodar os
testes, criar a tag `onda-1` e começar a Onda 2.
