# Vitriol — Status

## Onda atual

Onda 3 — Interação com o mundo: **concluída** (marco `marco/onda-3`). Próxima: Onda 4.

## Tarefas da Onda 3

- [x] 3A Mineração — segurar o botão esquerdo; o servidor confere alcance (5 blocos), dureza × força da
      ferramenta e tempo; desgasta a picareta; derruba a árvore inteira; bateia garimpa cascalho;
      rachaduras e moldura vermelha/branca no cliente
- [x] 3B Inventário — 40 espaços (10 na barra), pilhas de 99, ferramentas com durabilidade; barra,
      painel (E), nome do item, avisos; kit inicial de 10 tochas; descobertas com XP anunciado
- [x] 3C Iluminação — mapa de luz colorido por bloco: céu com dia e noite (dia de 20 min), luz mínima por
      camada, tochas colocáveis (botão direito) e tocha na mão
- [x] 3D Salvar e carregar — mundo inteiro compactado (~80 KB) + jogadores + hora; a cada 60 s e ao
      fechar; `.bak` de segurança

## Portão da Onda 3

- [x] Minerar coloca o item no inventário (testes + print)
- [x] Cavernas escuras e iluminadas por tochas (testes de luz + prints de caverna e noite)
- [x] Fechar e reabrir não perde nada (testes: grade, inventário, posição, descobertas, hora)
- [x] 57 testes passando no Godot 4.7.2 headless
- [x] Marco `marco/onda-3` no GitHub

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

## Pendências e observações

- Balanceamento (Onda 5): a picareta de ferro (limonita do Solo) pode chegar antes da de bronze
- Sem fabricação ainda (Onda 4): o jogador começa só com as mãos e 10 tochas; F4 dá um kit de teste
- Ainda sem arte de bloco colocado: argamassa, tijolo, tijolo refratário, vidro (entram com a
  construção, 4B). Os ícones de item já existem
- Itens que caem no chão não existem: com o inventário cheio, o bloco não quebra
- XP de descoberta já é anunciado, mas a maestria só passa a contar na Onda 5
- Exportação (Onda 9): incluir `*.json` no filtro de exportação para `data/generated/` e `art/`
- Desempenho: o mundo é desenhado inteiro ao entrar; a luz é recalculada só perto da câmera
- Busca oficial de marca no INPI e no USPTO (classes 9 e 41) — com o Gabriel

## Próxima onda

Onda 4 — Produção, 3 tarefas em paralelo:

- 4A Processos: fundição, vidro e reação química em estações (fornalha, forno de vidro), lidos dos dados
- 4B Construção: colocar e remover blocos para erguer estruturas
- 4C Arte de itens e estações: estações no mundo e blocos construídos (ícones já prontos)

## Última sessão

16/10/2026 — Onda 3 completa. O próximo passo é a Onda 4.
