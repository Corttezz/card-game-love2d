# Salão reativo, polish dos detritos (18/Out/2026)

Segunda passada (pedido do lead depois de olhar os quadros 1:1: "ficou natural
e pequeno, mas invisível"): mesmos TAMANHOS, o dobro da chuva espalhada por
1,0 s, filetes a cada 0,6 a 1,2 s com 5 a 8 partículas e 2 a 3 no hit, 12
flutuantes com alpha 0,5, penas de 8 a 12 px em zigue-zague, pedrinha
descansando 2,5 s. A causa da invisibilidade da 1ª passada estava em outro
lugar: a faixa de nascimento (y 16 a 40 da arte) mapeia para y 3 a 118 da
tela em 1080p (o cover-fit põe `oy = -74`), ou seja, ATRÁS da TopBar de
80 px; a poeira passava o primeiro segundo escondida. Faixa agora em y 34 a
62 (tela 89 a 224 px em 1080p, 102 a 186 em 1024x768).
Recortes 1:1 novos por chefe: `_drop03_1x.png` (cue + 0,3 s) e
`_repouso1x.png` (0,6 s antes do cue).

Folhas em `antes/` (engine de 17/Out, commit d4cc18cb) e `depois/` (este commit),
capturadas em 1920x1080 por
`CARDGAME_HEADLESS=1 TOOL_WINDOW=1920x1080 lovec . test_one screenshot_musica_reativa <chefe>:<cue>:seq:<pasta>`.
Por chefe e cue: `_seq.png` (8 quadros de 0,1 s a partir de 0,1 s antes do cue,
salão inteiro a 0,5x), `_teto1x.png` (os mesmos 8 quadros, recorte 1:1 do teto
sob a TopBar) e `_chao2x.png` (recorte 2x do chão em 1,1 / 1,5 / 2,2 s depois
do cue; no `antes/` os tempos eram 0,9 / 1,3 / 1,8 s).

Escala da arte em 1080p: 4,8 px por pixel da PNG. A unidade dos detritos é
`u = round(4,8 / 2) = 2 px` de tela.

## Contagem (pool vivo no quadro, impressa pelo tool)

| chefe / cue | repouso (flutuantes) | cue + 0,3 s |
|---|---|---|
| carrion_king drop | 54 (12) | 102 |
| abyss_tyrant drop | 18 (12) | 87 |
| tower_lich drop | 35 (12) | 89 |
| rot_colossus drop | 75 (12) | 127 |
| winter_monarch hit | 12 (12) | 50 |
| winter_monarch drop | 43 (12) | 95 |
| eclipse_queen hit | 0 (0) | 29 |

(A Rainha usa a faixa genérica `music_boss`, cujo primeiro hit está em
0,35 s: o salão ainda não tinha ativado 0,6 s antes.) No
`carrion_king_drop_drop03_1x.png` contam-se a olho ~30 pontos e colunas
(filetes de 5 a 8 pontos, uma pena lavanda sobre o estandarte, motes no
ar); no repouso, os 12 flutuantes de 2 px a alpha 0,55 somem no escuro do
salão: vejo 8 a 10, e o filete que acabou de cair. O Tirano é o pior caso
de contraste (poeira tan sobre basalto vermelho e lava): ~15 a 20 visíveis
em +0,3 s. O Monarca tem a neve própria do InteriorFX, os flutuantes se
misturam a ela.

## Perguntas

**Detrito maior que 10 px na tela?** Não. Dust/neve/esporo/mote: 1u ou 2u
(2 ou 4 px). Pedrinhas 1 a 3u (2 a 6 px), 8% delas 4 a 5u (8 a 10 px) e só na
chuva do drop. Lasca/gelo 1u x 2 a 3u (2 x 4 a 6 px). Pena 4 a 6u de
comprimento (8 a 12 px) x 1u, com ponta de 1u e, em diagonal, degrau a cada
2 células (pedido do lead: objeto visível). Antes: poeira 5 px, pedrinha até 10 x 10 px, lasca 5 x 15 px,
pena 10 x 5 px com cauda 5 px.

**Sobra algo "bloco"?** Não na folha. A pedrinha de 2u+ nasce com um canto
cortado (4 variantes) e TROCA a variante a cada 0,11 s enquanto cai (lê como
rolar), com uma célula de brilho no canto superior; ao assentar vira o
quadrado cheio e fica parada. A lasca alterna vertical/horizontal no mesmo
relógio. Dúvida honesta: o quadrado 2u cheio de 4 px ainda é um quadrado, em
pixel art não há como fugir disso; a variação de forma é o que o tira do
"bloco".

**A queda tem aceleração e quique?** Sim, medido no pool (não só na folha):
pedrinha nasce a 0 a 12 px/s de arte e acelera a 230 px/s² (teto 330), chega
ao chão em ~1,1 a 1,3 s; primeiro quique com restituição 0,32 (x 0,7 a 1,3
aleatório), segundo menor, assenta em ~2,2 s e descansa 2,5 s antes de sumir
em 0,45 s. Lascas idem com 170 px/s² e 0,26. Poeira: 38 px/s² com velocidade
terminal 46 (cai acelerando só no começo, depois constante, como poeira).
Pena e neve seguem leves com balanço. `abyss_tyrant_drop_chao2x` e
`carrion_king_drop_chao2x` mostram pedrinhas no ar em 1,1 s e assentadas com
a nuvenzinha em 1,5 e 2,2 s.

**A poeira some?** Sim. A nuvenzinha do pouso (3 a 4 partículas de 1u, cor
clara do estilo, alpha 0,5 a 0,6) sobe 3 a 11 px/s, freia e cai de volta, e
some em 0,3 a 0,55 s com alpha (1 - t)². Poeira caída some em 0,45 s. Nada
fica no chão além da pedrinha (2,5 s) e da pena (1,5 s).

**Algo passa na frente do chefe ou do HUD?** Não. `MusicReact.draw` continua
logo depois de `InteriorFX.draw` e antes do chefe, do HUD e das cartas (as
`_seq.png` mostram o corpo do chefe e a barra intactos em todos os quadros;
nos `_chao2x` as cartas da mão cobrem os detritos, nunca o contrário). O
flutuante do ar também nasce atrás.

## Tremor só no cenário

`carrion_king_drop_tremor_prova.png`: recorte do centro do salão em três
painéis, antes | impacto (offset forçado de 4 px para baixo) | diff
(amarelo = pixel mudou). O chão, o chefe e os detritos ficam amarelos; a
carta da mão, a barra de vida e o painel de intenção não (25,5% do recorte
mudou, tudo cenário). Em 1080p o tremor é vertical: a arte do salão encaixa
exata na largura e o deslocamento é clampado pela folga do cover-fit para
não abrir borda preta.

## Monarca de Inverno agora tem drop

`winter_monarch_drop_*`: a faixa não tinha drop com o limiar padrão de 7 dB;
`python tools/music_cues.py winter_monarch --drop-db 4` dá 3 (8,06 s, 33,66 s,
76,67 s; o último dentro do loop), conferidos em
`tools/preview_out/musica_reativa/cues_winter_monarch.png` (os três estão em
subida de energia depois de uma vala). Contagem: repouso 43 (12 flutuantes),
cue+0,3 s 95.

## O que mudou de movimento (de leve)

- Filetes: 5 a 8 partículas de 1u em coluna (gap 1,3 px de arte) saindo de um
  ponto do teto; 2 a 3 filetes no hit, 3 no drop e um a cada 0,6 a 1,2 s
  enquanto a faixa do chefe toca.
- Drop: filetes + 35% da chuva no instante, o resto espalhado por 1,0 s
  (antes era tudo num quadro e sumia em 0,3 s). Poeira 28 a 44 (Rei), 24 a
  36 (Lich, Tirano), neve 28 a 40, pedrinhas 4 a 8 (Rei) / 10 a 16 (Tirano),
  penas 2 a 4, lascas 6 a 10.
- Poeira no ar em repouso: 12 flutuantes de 1u (10 na Rainha), alpha 0,52 a
  0,55, 1 a 3 px/s de arte com balanço lento (brasa do tirano sobe), vida 6 a
  10 s; o salão já abre com eles (pré-preenchido na ativação, fase de vida
  aleatória).
- Chamas pintadas no hit: 0,35 → 0,45 por 0,28 → 0,32 s. Tremor intocado
  (1,6 / 3,2 px, cooldown 0,45 / 4 s).
- `reducedMotion`: nenhum filete, flutuante, chuva ou quique (mesma regra:
  zero detrito).

## Leitura honesta das folhas

- Rei-Carniça e Tirano: o drop lê (poeira tan 2 a 4 px caindo em filetes,
  pedrinhas claras quicando, penas roxas no Rei). O hit lê com a poeira de
  2u; só com 1u era quase invisível no quadro parado (por isso 40% dos motes
  de poeira são 2u).
- Lich: lascas roxas e poeira contra a janela da lua. Sutil, de propósito.
- Monarca: neve 2 a 4 px e gelo; o salão já tinha neve própria do
  InteriorFX, o acréscimo é discreto.
- Colosso e Rainha: só hit/drop da faixa genérica; esporos e motes de 2 a
  4 px. Discretos.
- O `_seq.png` a 0,5x quase não mostra os detritos: é a prova de que nada
  grande sobrou e de que nada cruza o chefe, não uma prova de que o efeito
  lê. O que lê em jogo é o MOVIMENTO contínuo (filetes + flutuantes), que o
  quadro parado não captura.

## Custo (`abyss_tyrant:drop:perf`, 1080p headless, segunda passada)

| quadro | med ms | p95 ms | draw calls | detritos vivos |
|---|---|---|---|---|
| salão sem detrito | 4,20 | 6,95 | 78 | 1 |
| drop + 0,35 s | 3,35 | 3,74 | 74 | 57 |
| quique + 1,2 s | 3,39 | 3,86 | 71 | 115 |
| mesmo quadro sem desenhar | 3,52 | 4,50 | 75 | 116 |

(1ª passada: 3,35 a 3,85 ms, 73 a 74 draws, pico 39.) Pool fixo de 256 (era
120), pico medido 116 no quique do Tirano, zero alocação por quadro; os
retângulos entram no lote da LÖVE, draw calls dentro do ruído (71 a 78 com
ou sem detrito).
