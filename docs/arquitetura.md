# Arquitetura base

Vitriol roda sempre como **cliente + servidor**, mesmo no solo. No solo, o servidor vive no mesmo processo
(servidor local); no multiplayer, o mesmo código roda num servidor dedicado. Isso evita reescrever o jogo
quando o multiplayer chegar (Onda 10).

```
 Cliente (client/)                     Servidor (core/server/)
 ┌──────────────────┐   comandos    ┌──────────────────────┐
 │ ClientSession    │ ────────────▶ │ GameServer (autoload)│
 │ (tela, entrada)  │               │  WorldState          │
 │                  │ ◀──────────── │  PlayerState         │
 └──────────────────┘    eventos    └──────────────────────┘
          ▲                                   ▲
          └──────── Transport (core/net/) ────┘
                    LocalTransport no solo
                    ENetTransport no multiplayer (Onda 10)
```

## Regras

1. **Só o servidor altera o estado.** O cliente nunca muda o mundo diretamente: ele envia um comando
   (`core/shared/commands.gd`) e reage aos eventos (`core/shared/events.gd`).
2. **Ticks fixos.** O servidor processa os comandos 20 vezes por segundo (`GameServer.TICK_RATE`), na
   ordem de chegada. `step_once()` processa um tick na hora, para testes.
3. **Transporte trocável.** `Transport` é a interface; `LocalTransport` liga cliente e servidor no mesmo
   processo. Um transporte de rede terá a mesma interface.
4. **Estado serializável.** `WorldState` e `PlayerState` expõem `to_dict()`, base para salvar e carregar
   (tarefa 3D) e para enviar estado pela rede.

## Mundo e movimento (Onda 2)

- **O servidor gera o mundo** (`world/world_generator.gd`) a partir de uma semente e o guarda em
  `WorldState.grid`. Ao entrar, o cliente recebe `world_snapshot` (cópia da grade) e depois `joined`.
- **O cliente move o próprio personagem** com `PlayerMotor` e envia `move` 20 vezes por segundo. Esperar
  o servidor a cada passo deixaria o controle travado num jogo de plataforma; é o mesmo modelo do
  Terraria.
- **O servidor confere cada posição** com o mesmo `PlayerMotor`: fora do mundo, dentro de um bloco ou
  rápida demais → manda `correction` com a última posição válida. Aceita → repassa `player_moved` aos
  outros jogadores.
- **Ações que mudam o mundo** são decididas pelo servidor. Minerar: o cliente manda `mine` enquanto o
  botão está apertado; o servidor confere alcance, dureza e ferramenta, conta o tempo, quebra o bloco,
  entrega o item (`inventory`) e avisa todos (`tile_changed`).

## Salvar e carregar (Onda 3)

`core/server/save_game.gd` grava `user://mundos/<nome>/mundo.json`: a grade inteira compactada (tiles e
paredes em zstd + base64, ~80 KB), a paleta de nomes, a hora do dia e os jogadores por nome (posição,
inventário, item selecionado, descobertas). Grava num `.tmp`, mantém a versão anterior como `.bak` e lê o
`.bak` se o principal estiver corrompido. Ao carregar, os tiles são lidos pelo nome: se os dados do jogo
mudarem de ordem, o mundo continua certo. Salva a cada 60 s e ao fechar.

```
Cliente                         Servidor
PlayerMotor.step() a 60 Hz
   └─ move (20 Hz) ───────────▶ confere com PlayerMotor.overlaps_solid()
                                 ├─ ok:    player_moved ─▶ outros clientes
   ◀────────────── correction ──┴─ falha: volta para a última posição válida
```

## Pastas por módulo

| Pasta | Conteúdo | Onda |
| --- | --- | --- |
| `core/server/` | GameServer, estado do mundo e dos jogadores | 1 |
| `core/net/` | Transportes cliente ↔ servidor | 1 |
| `core/shared/` | Comandos e eventos (contrato entre cliente e servidor) | 1 |
| `client/` | Cena principal, sessão do cliente e desenho do mundo (`WorldView`) | 1, 2 |
| `world/` | Grade de tiles, registro de tipos e gerador procedural | 2 (2A) |
| `player/` | Física do personagem (`PlayerMotor`), personagem na tela, comandos de teclado | 2 (2B) |
| `data_loader/` | Autoload `GameData`: dados de jogo de `data/generated/` | 2 (2C) |
| `art/` | Paleta, tiles e sprites | 1 (1D), 2 (2D) |
| `data/` | Esquema, conteúdo (CSV) e dados gerados (JSON) | 1 (1B, 1C) |
| `tools/` | Ferramentas de desenvolvimento (validador de dados) | 1 |
| `tests/` | Testes rodados no Godot em modo headless | 1 |

Cada tarefa paralela mexe só na sua pasta. Mudanças em `core/shared/` (o contrato) devem ser pequenas e
anotadas no STATUS.md, porque afetam todos os módulos.

## Testes

Na primeira vez, importe o projeto (gera o cache de classes):

```
godot --headless --path . --import
godot --headless --path . -s res://tests/run_tests.gd            # todos os testes
godot --headless --path . -s res://tests/run_tests.gd -- mundo   # só os que têm "mundo" no nome
godot --path . -s res://tests/captura.gd -- <pasta>               # roda o jogo e salva prints
godot --headless --path . -s res://world/export_map.gd -- <semente> <saida.png>   # mapa do mundo
```

Os testes ficam em `tests/test_*.gd`; cada método `test_*` é um teste (base em `tests/test_case.gd`).
