# Salão reativo, polish dos detritos (18/Out/2026)

Folhas em `antes/` (engine de 17/Out, commit d4cc18cb) e `depois/` (este commit),
capturadas em 1920x1080 por
`CARDGAME_HEADLESS=1 TOOL_WINDOW=1920x1080 lovec . test_one screenshot_musica_reativa <chefe>:<cue>:seq:<pasta>`.
Por chefe e cue: `_seq.png` (8 quadros de 0,1 s a partir de 0,1 s antes do cue,
salão inteiro a 0,5x), `_teto1x.png` (os mesmos 8 quadros, recorte 1:1 do teto
sob a TopBar) e `_chao2x.png` (recorte 2x do chão em 1,1 / 1,5 / 2,2 s depois
do cue; no `antes/` os tempos eram 0,9 / 1,3 / 1,8 s).

Escala da arte em 1080p: 4,8 px por pixel da PNG. A unidade dos detritos é
`u = round(4,8 / 2) = 2 px` de tela.

## Perguntas

**Detrito maior que 10 px na tela?** Não. Dust/neve/esporo/mote: 1u ou 2u
(2 ou 4 px). Pedrinhas 1 a 3u (2 a 6 px), 8% delas 4 a 5u (8 a 10 px) e só na
chuva do drop. Lasca/gelo 1u x 2 a 3u (2 x 4 a 6 px). Pena 3u x 1u + ponta
(6 x 2 px + 2 px). Antes: poeira 5 px, pedrinha até 10 x 10 px, lasca 5 x 15 px,
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
aleatório), segundo menor, assenta em ~2,2 s e descansa 1,4 s antes de sumir
em 0,45 s. Lascas idem com 170 px/s² e 0,26. Poeira: 38 px/s² com velocidade
terminal 46 (cai acelerando só no começo, depois constante, como poeira).
Pena e neve seguem leves com balanço. `abyss_tyrant_drop_chao2x` e
`carrion_king_drop_chao2x` mostram pedrinhas no ar em 1,1 s e assentadas com
a nuvenzinha em 1,5 e 2,2 s.

**A poeira some?** Sim. A nuvenzinha do pouso (3 a 4 partículas de 1u, cor
clara do estilo, alpha 0,5 a 0,6) sobe 3 a 11 px/s, freia e cai de volta, e
some em 0,3 a 0,55 s com alpha (1 - t)². Poeira caída some em 0,45 s. Nada
fica no chão além da pedrinha (1,4 s) e da pena (1,2 s).

**Algo passa na frente do chefe ou do HUD?** Não. `MusicReact.draw` continua
logo depois de `InteriorFX.draw` e antes do chefe, do HUD e das cartas (as
`_seq.png` mostram o corpo do chefe e a barra intactos em todos os quadros;
nos `_chao2x` as cartas da mão cobrem os detritos, nunca o contrário). O
flutuante do ar também nasce atrás.

## O que mudou de movimento (de leve)

- Filetes: 3 a 5 partículas de 1u em coluna (gap 1,3 px de arte) saindo de um
  ponto do teto; no hit, no drop e numa cadência contínua de 1 a cada 1,1 a
  2,4 s enquanto a faixa do chefe toca.
- Drop: 35% da chuva no instante, o resto espalhado por 0,7 s (antes era tudo
  num quadro e sumia em 0,3 s).
- Poeira no ar em repouso: até 6 a 8 flutuantes de 1u (alpha 0,32 a 0,42),
  1 a 3 px/s de arte com balanço lento (brasa do tirano sobe), vida 6 a 10 s.
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

## Custo (`abyss_tyrant:drop:perf`, 1080p headless)

| quadro | med ms | p95 ms | draw calls | detritos vivos |
|---|---|---|---|---|
| salão sem detrito | 3,66 | 6,29 | 73 | 0 |
| drop + 0,35 s | 3,35 | 4,02 | 73 | 18 |
| quique + 1,2 s | 3,56 | 4,70 | 74 | 39 |
| mesmo quadro sem desenhar | 3,85 | 4,67 | 73 | 28 |

Pool fixo de 160 (era 120; pico medido 49 no drop do tirano), zero alocação
por quadro, retângulos entram no lote da LÖVE (+0 a 1 draw call).
