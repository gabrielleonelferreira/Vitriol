# Vitriol — Status

## Onda atual

Onda 4 — Produção: **concluída** (marco `marco/onda-4`). Próxima: Onda 5.

## Tarefas da Onda 4

- [x] 4A Processos — fila de produção no servidor: estação por perto (6 blocos), materiais saem na hora,
      tempo da receita, saída no inventário, cancelar devolve; XP por área de maestria com níveis 1–10;
      receitas `xp` pedem nível; `experimentacao` ficam secretas; painel de fabricação (C) com o que
      falta e o porquê; progresso ao lado da barra
- [x] 4B Construção — botão direito coloca blocos, objetos e estações com regras de apoio (estação no
      chão, bloco encostado, ninguém preso); moldura branca/vermelha usa as mesmas regras do servidor;
      vidro deixa passar luz
- [x] 4C Arte — estações no mundo (fogueira, bancada, fornalha, forno, forno de vidro) com brasa animada
      e luz; tijolo, tijolo refratário, argamassa, vidro e vidro de tempestade construídos

## Portão da Onda 4

- [x] Cadeia completa testada: madeira → bancada → fornalha → tijolo → parede (teste
      `test_cadeia_mao_bancada_fornalha_tijolo` + prints)
- [x] Cobre fundido na fornalha dá descoberta e XP de metalurgia; nível 2 libera o estanho
- [x] Casinha de tijolo com janelas de vidro, noite com fornalha e tocha acesas (prints)
- [x] 68 testes passando no Godot 4.7.2 headless
- [x] Marco `marco/onda-4` no GitHub

## Decisões tomadas

- Motor: Godot 4.7+, renderizador Compatibility (roda em PCs mais fracos e suporta luz 2D)
- Resolução interna 640 × 360, escala inteira, filtro nearest; texto sem suavização
- Tile 16 × 16 px; personagem 16 × 32 px; caixa de colisão 10 × 28 px (cabe em túnel de 2 tiles)
- Solo roda como cliente + servidor local; comandos e eventos em `core/shared/`
- Movimento: o cliente simula o próprio personagem e o servidor valida (modelo do Terraria). Minerar,
  colocar e inventário: o servidor decide
- Física própria (`PlayerMotor`) em vez do motor de física do Godot: determinística, testável e usada
  pelo servidor para validar
- Conteúdo em CSV → validado → JSON em `data/generated/` (versionado, o jogo lê o JSON)
- `data/content`, `data/schema`, `docs` e `tools` têm `.gdignore`: o Godot não importa essas pastas
- Arquivos `.uid` e `.import` vão para o Git (recomendação do Godot 4.4+)
- Marcos de onda são branches `marco/onda-N` (o ambiente de desenvolvimento não consegue enviar tags)
- Mineração: tempo = (0,2 s + 0,35 s × dureza) ÷ velocidade; mãos (força 1) têm velocidade 0,6; cada
  ponto de força acima do necessário deixa 25% mais rápido
- Garimpo com bateia no cascalho: 60% cassiterita, 15% ouro aluvial, 25% cascalho
- Objetos colocáveis são itens de tipo `objeto` e viram tiles não sólidos; luz é dado (`luz_raio`,
  `luz_cor` em itens.csv)
- Luz mínima por camada: Solo 24%, Sedimentar 13%, Metamórfica 6% (ajustado em teste)
- Save guarda a grade inteira (não semente + diferenças): mudar o gerador não quebra mundos salvos
- Saves em `user://mundos/` = `%APPDATA%\Vitriol\mundos\` no Windows
- Rocha principal por camada vem de `geracao.csv` (forma `rocha`): Solo = terra, Sedimentar =
  calcário (3), Metamórfica = xisto (5)
- Mundo do MVP: 1200 × 260 tiles; gera em ~0,7 s; desenho inicial em ~1,3 s
- Arte gerada por código com a paleta oficial; ícones gerados para todo material e item (o gerador
  recusa terminar se algum ficar sem ícone)
- Encaixe dos blocos por máscara de 4 bits (16 versões por bloco)
- Primeira escola do MVP: Tempestária; a Pena de Ave-Trovão cai em tempestades (fonte provisória)
- Maestria básica (XP e níveis) foi adiantada da Onda 5 para a 4: sem ela, a cadeia do vidro
  (argamassa e tijolo refratário pedem nível 2) não fecha. Ficam para a 5A: experimentação, cascata de
  descobertas e bônus de velocidade por nível
- Fabricar consome os materiais ao entrar na fila (não ao terminar): o inventário mostra o que sobra
- Fila de até 20 trabalhos por jogador; anda mesmo longe da estação (a estação é conferida ao pedir)
- Tochas: 2 madeiras = 1 tocha de galho; 1 madeira + 1 carvão = 4 tochas
- Fundir vidro é receita inicial (precisa do forno de vidro, que já pede nível 3 de construção)

## Pendências e observações

- Balanceamento (Onda 5): a picareta de ferro (limonita do Solo) pode chegar antes da de bronze
- Receitas secretas (bronze, coque, fulgurito) aparecem como `???` e ainda não há como descobri-las:
  entram com a experimentação (5A)
- Itens que caem no chão não existem: com o inventário cheio, o bloco não quebra e o item fabricado
  espera na fila
- Estações não mudam de aparência quando estão trabalhando (a brasa anima sempre)
- Exportação (Onda 9): incluir `*.json` no filtro de exportação para `data/generated/` e `art/`
- Desempenho: o mundo é desenhado inteiro ao entrar; a luz é recalculada só perto da câmera
- Busca oficial de marca no INPI e no USPTO (classes 9 e 41) — com o Gabriel

## Próxima onda

Onda 5 — Progressão e magia, 4 tarefas em paralelo:

- 5A Experimentação: misturar materiais sem receita, cascata de descobertas, bônus de velocidade por
  nível de maestria
- 5B Tempestária: tempestades, raios que formam fulgurito, primeira escola de magia
- 5C Áudio: sons de mineração, estações e ambiente
- 5D Movimento na construção: portas que abrem ao encostar, plataformas entre andares (sobe pulando,
  desce com ↓), escada de mão que se coloca sozinha enquanto o jogador sobe, corda jogada do alto

Decidido para depois: fachada das casas e guincho de mina (Onda 6), Poção de Retorno e círculos de
transmutação (Onda 7), defesa em camadas, portas com selo e Carta do Território (Onda 10). O jogo fica
sempre de lado; a vista de cima é só a Carta do Território (administrar e viajar).

## Última sessão

17/10/2026 — Onda 4 completa. O próximo passo é a Onda 5.
