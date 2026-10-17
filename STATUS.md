# Vitriol — Status

## Onda atual

Onda 5 — Progressão e magia: **tarefas concluídas**; falta só a partida de teste com o Gabriel para
fechar o portão (marco MVP).

## Tarefas da Onda 5

- [x] 5D Movimento na construção — portas (abrem ao encostar, 2 de altura), plataformas (sobe pulando,
      S/↓ atravessa), escada de mão (sobe com W; na mão, se coloca sozinha enquanto sobe), rolo de corda
      (desenrola até 20 blocos); fibra vegetal das folhas; 7 testes novos
- [x] 5A Descoberta e maestria — aba Experimentar (mistura sem receita, 5 tipos de pista, errar gasta
      1 de cada); cascata de raros (electro = ouro + prata, novo); nível de maestria: +6% de velocidade
      e +5% de durabilidade por nível; 7 testes novos
- [x] 5B Tempestária — tempestades com chuva e raios; raio funde areia em fulgurito (brilha); Pena de
      Ave-Trovão cai uma vez por tempestade e desperta a Tempestária: Q invoca raio (5 s), salto do
      vento (pulo duplo), vidro de tempestade liberado; F7 testa; 6 testes novos
- [x] 5C Áudio e partículas — 25 sons gerados por síntese (mineração por material, quebra, passos,
      portas, escada, pulo, trovão, chuva e fogo contínuos, descoberta, nível, pronto, falha); lascas,
      poeira, faíscas do raio, fumaça e brasas das estações; M liga/desliga o som; 2 testes novos

## Portão da Onda 5 (marco MVP)

- [x] Maratona automática (`tests/maratona.gd`): um robô joga do primeiro bloco ao primeiro raio num
      mundo 1200 × 260 — madeira, sílex, picareta, bancada, argila, calcário, fornalha, carvão, cobre,
      tijolo, escada, salvar e voltar, tempestade, pena, Tempestária, raio invocado. 45 min de jogo em
      57 s, 4 tempestades, 127 raios, tick mais lento 8,5 ms, **0 bugs**
- [x] Resistência com tela (4 min reais andando, pulando, minerando, com tempestade): FPS médio 61 e
      mínimo 43 no renderizador por software do ambiente de desenvolvimento, sem erros
- [x] 90 testes passando no Godot 4.7.2 headless
- [ ] **Partida de 30 a 60 minutos com o Gabriel** seguindo `docs/teste-de-jogo.md`, com a lista de bugs
- [ ] Marco `marco/onda-5` no GitHub (depois da partida)

## Onda 4 (concluída, marco `marco/onda-4`)

Fabricação com fila e painel (C), maestria básica, construção com o mouse, arte das estações.

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
- Jogo sempre de lado, sem troca de cena ao entrar em casa; a vista de cima será só a Carta do
  Território (Onda 10)
- Porta não bloqueia a física (só a luz); abre e fecha só no desenho, sem estado no servidor
- Experimentar errado custa 1 de cada material (tentativa e erro tem preço, mas a pista ajuda)
- Fulgurito virou bloco (dureza 2, precisa de picareta); a receita "formar fulgurito" do raio fica
  como referência de processo, quem faz é a tempestade
- Electro (ouro + prata, liga real das primeiras moedas) entrou como receita secreta de cascata
- Escada automática: segurar W com a escada na mão constrói para cima até soltar (dá para fazer torre)
- Fundir vidro é receita inicial (precisa do forno de vidro, que já pede nível 3 de construção)

## Pendências e observações

- Balanceamento (Onda 5): a picareta de ferro (limonita do Solo) pode chegar antes da de bronze
- Raios ainda não machucam (não há vida no MVP); para-raio é da Onda 6
- Tempestade não fica salva: ao recarregar o mundo, o céu volta limpo
- Itens que caem no chão não existem: com o inventário cheio, o bloco não quebra e o item fabricado
  espera na fila
- Estações não mudam de aparência quando estão trabalhando (a brasa anima sempre)
- Exportação (Onda 9): incluir `*.json` no filtro de exportação para `data/generated/` e `art/`
- Desempenho: o mundo é desenhado inteiro ao entrar; a luz é recalculada só perto da câmera
- Busca oficial de marca no INPI e no USPTO (classes 9 e 41) — com o Gabriel

## Próximo passo

Partida de teste do Gabriel (`docs/teste-de-jogo.md`) → corrigir a lista de bugs → marco
`marco/onda-5` → Onda 6 (mundo completo).

Decidido para depois: fachada das casas e guincho de mina (Onda 6), Poção de Retorno e círculos de
transmutação (Onda 7), defesa em camadas, portas com selo e Carta do Território (Onda 10). O jogo fica
sempre de lado; a vista de cima é só a Carta do Território (administrar e viajar).

## Última sessão

17/10/2026 — Onda 4 completa; Onda 5 completa (5D, 5A, 5B, 5C) e maratona automática sem bugs. Falta a
partida de teste com gente.
