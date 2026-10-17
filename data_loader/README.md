# data_loader/

Carrega os dados de jogo de `data/generated/*.json` no autoload **GameData** (`data_store.gd`).

```gdscript
GameData.get_material("malaquita")["nome"]      # "Malaquita"
GameData.is_block("calcario")                   # true
GameData.recipes_for_station("fornalha")        # ["carvoaria", "fundir_cobre", ...]
GameData.recipes_producing("lingote_cobre")     # ["fundir_cobre"]
GameData.layer_rocks()                          # ["terra", "calcario", "xisto"]
GameData.generation_for_layer(3)                # regras de veios da camada 3
```

Se um JSON faltar, estiver corrompido ou com versão diferente, `GameData.loaded` fica `false` e
`GameData.errors` diz o motivo. Para gerar os JSON, rode `python3 tools/build_data.py`.
