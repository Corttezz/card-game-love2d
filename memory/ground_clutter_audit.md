---
name: ground_clutter_audit
description: Auditoria dos detalhes de chão (GroundClutter) por ato, 25/Out/2026: o que ficou, o que saiu, o que foi refeito, por que brotavam no meio da tela e como agora nascem atrás da crista
type: project
---

# Detalhes de chão (GroundClutter): auditoria e correção (25/Out/2026, frente CLUTTER)

Queixa do dono: "algumas dessas coisas brotam do chão, simplesmente aparecem" e "algumas parecem colagem,
destoam do ambiente do ato, principalmente no ato 3".

## Por que brotavam (causa raiz)

`GroundClutter.collect` só listava itens com t ≥ `tMin` (0,50) e esmaecia o alfa de t 0,50 a 0,58
(`tFade`). Em t 0,5 o item já está na METADE da tela (y ≈ 790 em 1080p, crista em ≈ 464), então andando ele
nascia do nada no meio do campo, em ~0,1 s. O detector antigo não pegava: o alfa subia em degraus menores que
`ALPHA_STEP` e o primeiro quadro tinha alfa < `MIN_A`. Medido no main 855e8b51 com a regra nova do
detector: `estrada_seq 3:3esq` = 31 `clutter:brota` (folha `tools/preview_out/chao_itens/antes_seq_ato3_3esq_flags.txt`).
Outros cortes à vista que existiam: encruzilhada cortava/esmaecia TUDO além de rel 8 (não só o que caía no
braço), item sob a mão saía da lista (e voltava em alfa 0 no meio da tela), troca de bioma trocava o
catálogo no mesmo quadro.

## Como ficou

- Mesmo caminho das árvores e postes: o item é decidido pelo hash da célula de z (nascimento), existe de
  rel -9 até a crista no `nearPass` e, de `REL_CREST` a `REL_CREST + EMERGE_BAND`, no passe de trás
  (`GroundClutter.collectBehind/drawBehind`, chamados por `drawPropsBehind` intercalados por z com os props
  de trás), afundado `(1 - em) × altura` atrás da crista e coberto pelo domo. Na travessia da crista a
  posição (t = 0, mesma lateral) e a escala batem (`test_clutter_continuity`, desvio ≤ 2 px).
- Nada some na tela: sai pela borda de baixo (corte só com o topo abaixo da tela) ou pelas laterais.
  Item sob a mão / no braço da encruzilhada / na frente do castelo fica na lista com alfa (nunca sai).
- Encruzilhada: em vez de "tudo além de rel 8", só o que cai no corredor de um braço esmaece, com a mesma
  conta dos props (`LMG.clutterForkK`); castelo na crista: mesma regra de t < 0,36 dos props
  (`LMG.clutterCastleK`).
- Troca de bioma: os dois catálogos ao mesmo tempo, velho em `1 - k` e novo em `k` (k = blend do
  `WorldRoad._blend`, smoothstep).
- Sombra: `cast` (projetada pelo `ShadowEngine`) e `contact` (faixa do `ContactShadow`) por kind; `solid`
  liga os dois + tufos de grama na base (`requireTufts`). Sombra entra em rampa de t 0 a 0,20
  (`shadowT`), sem degrau na crista. `PropVariation` por item (tom ±5 %, brilho ±10 %, escala ±10 % nos
  sólidos, fase de vento). Cor: `SceneGrade.color(família, t)` como antes; `LightSpill` (poça do poste)
  mantido no draw.
- Detector: `estrada_seq.checkClutter` acusa `clutter:brota` (item novo com o topo abaixo da crista +
  2 % da altura, fora das bordas, nas fases de viagem/chegada/partida/marco) e `clutter:some_na_tela`. Vale
  para `estrada_seq`, `estrada_fluxo`, `test_fork_sequence` e `test_fork_flow`.

## Auditoria por ato (capturas 1920x1080, recortes 3x em `tools/preview_out/chao_itens/`)

| Ato | Kind | Arte | Veredito | Por quê |
|---|---|---|---|---|
| 1 campos | tuft | fields_tuft_0 | fica (+sombra leve) | assenta na grama, paleta do bioma |
| 1 | flowers | fields_flowers_0 | fica (+sombra leve) | idem |
| 1 | rock | fields_rock_0 | fica | já recolorida na revisão de cenas; tem contato e sombra |
| 1 | stump | fields_stump_0 | fica | escala e cor do bioma |
| 2 planalto | grass | highlands_grass_0..2 | fica (+sombra) | verde-petróleo do bioma |
| 2 | litter | highlands_litter_0..1 | fica | já sem ponta creme (rodada 4) |
| 3 abismo | embers | abyss_embers_0..3 (+anim) | SAI | montinho preto com lascas laranja chapadas: "brasa" que não emite luz lia como adesivo/confete, sem sombra, mais preto que o chão |
| 3 | rock | abyss_rock_0 (rocha de lava) | SAI do clutter | rocha lilás com veio de lava claro: o pixel mais claro do chão, não emite luz, matiz frio contra o chão marrom-vermelho. O PNG continua como PROP (`propWeights`), fora do escopo |
| 3 | thorns | abyss_thorns_0..2 (novo) | NOVO | espinheiro queimado baixo, mesma madeira ameixa e brasa miúda dos `abyss_bush`; sombra projetada + contato |
| 3 | cinders | abyss_cinders_0..2 (novo) | NOVO | galhos carbonizados caídos (sólido: contato, sombra, tufos) |
| 3 | stones | abyss_stones_0..2 (novo) | NOVO | basalto ameixa-cinza das pedras da ruína, sem lava (família rock) |
| 4 gelo | drift | frost_drift_0..2 | fica | neve do bioma, contorno igual aos pinheiros |
| 4 | rock | frost_rock_0 | fica | idem |
| 5 pântano | reeds | marsh_reeds_0..2 | fica (+sombra) | oliva do bioma |
| 5 | roots | marsh_roots_0..2 | fica | idem |
| 5 | mushroom | marsh_mushroom_0 | SAI do clutter | verde-ciano néon, o pixel mais claro do primeiro plano à noite e sem luz própria (regra: clutter nunca é o pixel mais claro). O PNG segue como PROP |
| 6 crepúsculo | blooms | dusk_blooms_0..2 | fica (+sombra leve) | violeta e âmbar do bioma |
| 6 | leaves | dusk_leaves_0..2 | fica (+contato) | folhas chatas no chão |

Arte nova: `tools/pixellab_chao_itens.py` (mesmo `create_image_pro` e prompt diorama do
`pixellab_primeiro_plano.py`, estilo `abyss_bush_0` / `abyss_ruin_0`), 3 jobs, 41 candidatas, folhas em
`tools/preview_out/chao_itens/pixellab/folha_*.png`; escolhidas thorns 0/3/5, cinders 0/12/7, stones 3/5/7
(sem as tiras de entulho flutuante que várias candidatas de pedra trouxeram).

## Travas

- `love . test_one test_clutter_continuity` (novo, no `test_all`): seis biomas, câmera andando 48 unidades,
  zero item nascido fora da faixa de trás da crista, zero salto na travessia, zero sumiço na tela, alfa sem
  degrau, troca de bioma em crossfade.
- `estrada_seq` / `estrada_fluxo` com `checkClutter` (0 flags).
- `test_sombras_item` / `bancada_sombras` leem `GroundClutter.casts/contacts`.
