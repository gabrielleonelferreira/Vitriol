# Vitriol — Status

## Onda atual

Onda 2 — Esqueleto técnico: **concluída** (marco `marco/onda-2`). Próxima: Onda 3.

## Tarefas da Onda 2

- [x] 2A Mundo em tiles e geração — `world/`: grade, registro de tiles, gerador procedural (Planícies,
      3 camadas, lagos com margens e leito, veios, cavernas, árvores, base indestrutível)
- [x] 2B Personagem — `player/`: física própria contra a grade (coyote time, pulo guardado, altura
      variável, degrau automático, água), animação, câmera; servidor valida posições
- [x] 2C Carregador de dados — autoload `GameData`; regras de geração em `data/content/geracao.csv`
- [x] 2D Arte base — `tools/art/gerar_arte.py`: tiles, paredes, minérios sobre a rocha, bordas,
      personagem em 7 camadas (contorno + 6 partes)

## Portão da Onda 2

- [x] O personagem anda, pula e cai por um mundo gerado com três camadas, com a arte base
      (conferido em prints: superfície, caverna sedimentar, caverna metamórfica)
- [x] Todos os dados carregam sem erro (`GameData`, `tools/build_data.py`)
- [x] 32 testes passando no Godot 4.7.2 headless
- [x] Marco `marco/onda-2` no GitHub

## Decisões tomadas

- Motor: Godot 4.7+, renderizador Compatibility (roda em PCs mais fracos e suporta luz 2D)
- Resolução interna 640 × 360, escala inteira, filtro nearest
- Tile 16 × 16 px; personagem 16 × 32 px; caixa de colisão 10 × 28 px (cabe em túnel de 2 tiles)
- Solo roda como cliente + servidor local; comandos e eventos em `core/shared/`
- Movimento: o cliente simula o próprio personagem e o servidor valida (modelo do Terraria). Ações que
  mudam o mundo serão sempre decididas pelo servidor
- Física própria (`PlayerMotor`) em vez do motor de física do Godot: determinística, testável e usada
  pelo servidor para validar
- Conteúdo em CSV → validado → JSON em `data/generated/` (versionado, o jogo lê o JSON)
- `data/content`, `data/schema`, `docs` e `tools` têm `.gdignore`: o Godot não importa essas pastas
  (ele trataria os CSV como tradução)
- Arquivos `.uid` e `.import` vão para o Git (recomendação do Godot 4.4+)
- Marcos de onda são branches `marco/onda-N` (o ambiente de desenvolvimento não consegue enviar tags)
- Mineração: `dureza_bloco` (esforço) separada de `dureza_mohs` (real); picaretas têm
  `poder_mineracao` e `durabilidade`. Sílex e cobre têm o mesmo poder (4); o cobre dura mais
- Rocha principal por camada vem de `geracao.csv` (forma `rocha`): Solo = terra, Sedimentar =
  calcário (3), Metamórfica = xisto (5)
- Mundo do MVP: 1200 × 260 tiles; gera em ~0,7 s; desenho inicial em ~1,3 s
- Arte gerada por código com a paleta oficial; minérios desenhados por cima da rocha da camada
- Primeira escola do MVP: Tempestária; a Pena de Ave-Trovão cai em tempestades (fonte provisória)

## Pendências e observações

- Balanceamento (Onda 5): a picareta de ferro (limonita do Solo) pode chegar antes da de bronze.
  Historicamente o bronze veio antes; dá para segurar o ferro pelo nível de maestria em
  `reduzir_limonita`
- Ainda sem arte (blocos que só aparecem quando construídos ou garimpados): argamassa, tijolo, tijolo
  refratário, vidro, vidro de tempestade, cassiterita, ouro aluvial → Onda 4 (4C)
- O subsolo ainda aparece claro: a escuridão por camada vem com a iluminação (3C)
- Exportação (Onda 9): incluir `*.json` no filtro de exportação para `data/generated/` e `art/`
- Desempenho: o mundo é desenhado inteiro ao entrar. Se mundos maiores pesarem, desenhar por pedaços
- Busca oficial de marca no INPI e no USPTO (classes 9 e 41) — com o Gabriel

## Próxima onda

Onda 3 — Interação com o mundo, 4 tarefas em paralelo:

- 3A Mineração: quebrar blocos conforme a dureza e a picareta (servidor decide, cliente redesenha)
- 3B Inventário: guardar, empilhar e mostrar itens
- 3C Iluminação dinâmica: escuridão por camada, tochas, lava e céu
- 3D Salvar e carregar: mundo (semente + alterações) e jogador

## Última sessão

16/10/2026 — Onda 2 completa. O próximo passo é a Onda 3.
