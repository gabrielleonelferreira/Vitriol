# Vitriol: World of Alchemists

Sandbox 2D de mineração, construção e alquimia, feito em Godot 4. O jogador desce na terra, refina
materiais por processos com base real e usa magia para criar o que a ciência sozinha não alcança.

> V.I.T.R.I.O.L. — *Visita Interiora Terrae Rectificando Invenies Occultum Lapidem*
> "Visite o interior da terra e, retificando, encontrará a pedra oculta."

## Abrir o projeto

1. Instale o [Godot 4.7 ou mais recente](https://godotengine.org/download) (versão padrão, não a .NET).
2. No Godot, **Importar** e escolha o arquivo `project.godot` desta pasta.
3. Rode com **F5**.

| Tecla | Ação |
| --- | --- |
| A / D ou ← / → | Andar |
| Espaço, W ou ↑ | Pular (segure para pular mais alto; na água, nada). Na escada ou corda, sobe |
| S ou ↓ | Descer escada e corda; em cima de uma plataforma, cai através dela |
| Botão esquerdo (segurar) | Minerar o bloco sob o mouse (alcance de 5 blocos) |
| Botão direito | Colocar o item selecionado: blocos (tijolo, vidro, terra…), tochas e estações. Moldura branca = pode, vermelha = não |
| C | Abrir a fabricação: clique em **Fazer** (Shift + clique faz 5). Precisa da estação por perto. Na aba **Experimentar**, misture materiais sem receita |
| 1 a 0 ou rodinha do mouse | Escolher o espaço da barra |
| E ou I | Abrir o inventário (clique em dois espaços para trocar) |
| M | Liga e desliga o som |
| F3 | Mostrar ou esconder as informações de depuração |
| Q | Tempestária desperta: invoca um raio onde o mouse aponta (espera de 5 s) |
| F4 | Kit de teste: picaretas, bateia e tochas (só na versão de desenvolvimento) |
| F7 | Começa uma tempestade agora (só na versão de desenvolvimento) |

Primeiros passos: derrube uma árvore (madeira), faça uma **Bancada** à mão e coloque-a no chão; na
bancada, faça a **Fornalha de argila** (argila + calcário). Perto da fornalha dá para fazer carvão,
fundir cobre e cozer tijolos.

Receitas secretas (como o bronze) só aparecem experimentando: escolha a estação, clique nos
materiais para montar a mistura e em **Misturar**. Errar gasta 1 de cada material e dá uma pista
(proporção errada, estação errada, falta ingrediente, material demais). Cada nível de maestria deixa as
receitas da área 6% mais rápidas e as ferramentas feitas nela 5% mais duráveis.

**Tempestades** chegam de tempos em tempos (a primeira, uns 5 a 8 minutos depois de entrar). Raios
que caem na areia viram **fulgurito**, um vidro natural que brilha; minere com picareta. Uma vez por
tempestade cai uma **Pena de Ave-Trovão**, brilhando no chão: pegá-la desperta a **Tempestária**. Com
ela, Q invoca raios, um segundo pulo no ar dá o salto do vento, e no forno de vidro o fulgurito com
vidro vira **vidro de tempestade**, que brilha.

Para construir e explorar: **porta** (bancada, 6 madeiras) abre sozinha quando você encosta;
**plataforma** e **escada de mão** saem de 1 madeira, à mão. Com a escada na mão, segure W e ela se
coloca sozinha enquanto você sobe — é assim que se sai de um buraco fundo. O **rolo de corda** (3 fibras,
que caem das folhas ao derrubar árvores) desenrola até 20 blocos para baixo.

O jogo salva sozinho a cada minuto e ao fechar a janela. No Windows os saves ficam em
`%APPDATA%\Vitriol\mundos\`. Para começar um mundo novo, apague a pasta `mundo_1` ou rode com
`-- --novo`.

## Comandos úteis

```
python3 tools/build_data.py      # valida o conteúdo (CSV) e gera os dados do jogo
python3 tools/check_project.py   # confere os caminhos res:// do projeto
python3 tools/art/gerar_arte.py  # gera de novo a arte base (tiles e personagem)
python3 tools/audio/gerar_sons.py # gera de novo os sons (síntese, sem arquivos de terceiros)
godot --headless --path . --import
godot --headless --path . -s res://tests/run_tests.gd
godot --headless --path . -s res://tests/maratona.gd -- 45   # robô joga 45 min acelerados
```

## Documentos

| Arquivo | Conteúdo |
| --- | --- |
| [STATUS.md](STATUS.md) | Onda atual, tarefas, decisões e próximo passo. **Ler antes de qualquer sessão.** |
| [docs/arquitetura.md](docs/arquitetura.md) | Cliente + servidor local, fabricação, maestria, construção, pastas |
| [docs/esquema-de-dados.md](docs/esquema-de-dados.md) | Materiais, itens e receitas em CSV |
| [docs/guia-de-arte.md](docs/guia-de-arte.md) | Paleta, grade, personagem em partes, iluminação |
| [docs/marca.md](docs/marca.md) | Verificação preliminar do nome |
| [docs/teste-de-jogo.md](docs/teste-de-jogo.md) | Roteiro da partida de teste e modelo da lista de bugs |

O documento de design completo e o plano em ondas estão nos documentos do projeto no Claude.
