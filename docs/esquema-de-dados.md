# Esquema de dados

Todo o conteúdo do jogo (materiais, itens e receitas) vive em planilhas CSV, não no código. Assim o
conteúdo cresce para centenas ou milhares de itens sem mexer no motor, e mods podem acrescentar arquivos.

```
data/content/*.csv  ──tools/build_data.py──▶  data/generated/*.json  ──data_loader/ (2C)──▶  jogo
   (você edita)          (valida e converte)       (o jogo lê; versionado)
```

Depois de editar um CSV, rode na raiz do repositório:

```
pip install jsonschema
python3 tools/build_data.py
```

O script valida tudo e só gera o JSON se não houver erro. Os esquemas formais (JSON Schema) estão em
`data/schema/`.

## materiais.csv

| Coluna | O que é | Exemplo |
| --- | --- | --- |
| id | Identificador único, minúsculas e `_` | `lingote_cobre` |
| nome | Nome exibido | Lingote de cobre |
| categoria | bloco, mineral, minerio, metal, combustivel, quimico, organico, liquido, vidro, magico | metal |
| tier | comum, raro, epico, mitico, primordial | comum |
| dureza_bloco | Esforço para minerar (0–10). Rochas usam Mohs real; agregados soltos, valores baixos. Vazio = não é bloco | 3.5 |
| dureza_mohs | Dureza real (Mohs), quando existe | 3 |
| densidade_g_cm3 | Densidade real; define o peso | 8.96 |
| ponto_fusao_c | Ponto de fusão real (°C); define a resistência ao calor | 1085 |
| condutividade | Condutividade elétrica relativa, 0–10 (prata = 10) | 9 |
| afinidade_arcana | Afinidade com magia, 0–10 | 6 |
| escola_afim | ignarquia, tempestaria, hibernia, teluria, verdancia, umbra (ou vazio) | tempestaria |
| fonte | mineracao, coleta, bioma, evento, criatura, processo, abismo | processo |
| fonte_detalhe | Onde ou como se obtém, em texto | Fundição de malaquita |
| ferramenta_coleta | Item necessário para coletar (ou vazio) | bateia |
| camadas | Camadas onde aparece, separadas por `;` (1 Solo … 6 Abismo) | 1;2 |
| maestria | metalurgia, quimica, vidraria, construcao, arcano | metalurgia |
| xp_descoberta | XP ao descobrir pela primeira vez | 10 |
| base_real | O fundo de verdade | Cobre, metal das primeiras ligas |
| descricao | Texto do jogo | — |

## itens.csv

Ferramentas, estações de trabalho e fenômenos que funcionam como estação (o raio).

| Coluna | O que é |
| --- | --- |
| id, nome | Como em materiais |
| tipo | ferramenta, estacao, objeto (colocável no mundo, ex.: tocha), fenomeno |
| material_base | Material principal (define a aparência e a qualidade) |
| poder_mineracao | Minera blocos com dureza_bloco até este valor. Mãos = 1 |
| durabilidade | Usos até quebrar |
| temperatura_max_c | Temperatura máxima da estação |
| descricao | Texto do jogo |
| luz_raio | Alcance da luz em blocos quando colocado ou segurado (vazio = não ilumina). Vale também para estações (fornalha, fornos) |
| luz_cor | Cor da luz, hex da paleta sem # (ex.: `e2b33c`) |

O item `mao` representa fazer algo à mão, sem estação.

## receitas.csv

| Coluna | O que é | Exemplo |
| --- | --- | --- |
| id, nome | Identificador e nome | `fundir_cobre` |
| estacao | id de um item do tipo estacao ou fenomeno | fornalha |
| processo | queima, pirolise, fundicao, reducao, liga, cementacao, calcinacao, coccao, mistura, fusao_vidro, descarga_eletrica, montagem | fundicao |
| entradas | `id:quantidade` separados por `;` | `malaquita:2;carvao_vegetal:1` |
| saidas | Mesmo formato | `lingote_cobre:1` |
| temperatura_min_c | Temperatura exigida; não pode passar da estação | 1085 |
| requer | Condições alternativas separadas por `\|` (basta uma) | `evento:tempestade\|magia:tempestaria` |
| tempo_s | Tempo base em segundos, antes do bônus de maestria | 8 |
| maestria | Área que recebe o XP | metalurgia |
| xp | XP por execução | 5 |
| desbloqueio | inicial, xp ou experimentacao | xp |
| nivel_maestria | Nível exigido quando desbloqueio = xp | 2 |
| base_real | O fundo de verdade | — |

## geracao.csv

Onde cada material aparece no mundo gerado. Uma linha por regra; o mesmo material pode ter várias.

| Coluna | O que é |
| --- | --- |
| material | id do material (precisa ser um bloco) |
| camada | 1 Solo, 2 Sedimentar, 3 Metamórfica… (precisa estar nas `camadas` do material) |
| forma | `rocha` (preenche a camada; uma por camada), `veio`, `bolsao`, `superficie` (afloramento), `margem` (em volta de lagos), `leito` (fundo de lagos) |
| frequencia | veio, bolsão e superfície: ocorrências a cada 100 colunas de largura. margem: por lago |
| tamanho_min, tamanho_max | Tamanho de cada ocorrência, em blocos (veio) ou raio (bolsão, margem) |
| observacao | Nota livre |

A rocha principal de cada camada vem daqui (forma `rocha`) e é usada pela simulação de progressão.

## Regras conferidas pelo validador

1. Cada registro segue o esquema (tipos, valores permitidos, faixas).
2. Ids únicos entre materiais e itens.
3. Toda entrada, saída, estação, ferramenta e material base existe.
4. A temperatura da receita cabe na estação.
5. Desbloqueio por xp tem nível; os outros não.
6. Material com fonte `processo` é produzido por alguma receita.
7. Regras de geração: material é bloco, a camada é coerente, uma rocha principal por camada.
8. **Progressão:** partindo de mãos vazias, todo material e item é alcançável, respeitando dureza dos
   blocos, poder das picaretas, ferramentas de coleta, estações e escolas despertadas (um material
   mítico com `escola_afim` desperta aquela escola).

## Regra de descoberta em cascata (implementada na Onda 5)

Descobrir um material raro libera todas as receitas que o usam, exceto as que também exigem outro
material raro ou de tier maior que ainda não foi descoberto. Essas continuam secretas.
