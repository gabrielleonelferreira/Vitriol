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
| Espaço, W ou ↑ | Pular (segure para pular mais alto; na água, nada) |
| F3 | Mostrar ou esconder as informações de depuração |

## Comandos úteis

```
python3 tools/build_data.py      # valida o conteúdo (CSV) e gera os dados do jogo
python3 tools/check_project.py   # confere os caminhos res:// do projeto
python3 tools/art/gerar_arte.py  # gera de novo a arte base (tiles e personagem)
godot --headless --path . --import
godot --headless --path . -s res://tests/run_tests.gd
```

## Documentos

| Arquivo | Conteúdo |
| --- | --- |
| [STATUS.md](STATUS.md) | Onda atual, tarefas, decisões e próximo passo. **Ler antes de qualquer sessão.** |
| [docs/arquitetura.md](docs/arquitetura.md) | Cliente + servidor local, pastas por módulo |
| [docs/esquema-de-dados.md](docs/esquema-de-dados.md) | Materiais, itens e receitas em CSV |
| [docs/guia-de-arte.md](docs/guia-de-arte.md) | Paleta, grade, personagem em partes, iluminação |
| [docs/marca.md](docs/marca.md) | Verificação preliminar do nome |

O documento de design completo e o plano em ondas estão nos documentos do projeto no Claude.
