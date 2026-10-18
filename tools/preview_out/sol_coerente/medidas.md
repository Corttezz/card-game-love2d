# Sol coerente: onde está o astro que o jogador vê (18/Out/2026, frente sol-coerente)

Captura: `screenshot_enemy_scene <N>_battle` em 1920x1080 (tod 0,65 e 0,95) e
`lovec . test_one screenshot_sol_coerente <rotulo>` (mundo em 1920x1080: os 8 andares do ato com
`camZ = (andar-1) × 20` e a encruzilhada em tod 0,65 e 0,95; no mesmo quadro o disco desenhado é
pintado de magenta e os pixels magenta são contados). Medição automática do astro pintado
(`G > 0,74 R`, agrupado por coluna) conferida a olho nas folhas.

Frações: x = fração da largura da tela; y = fração da altura do quadro 1080.

## Antes (main d6406956)

| bioma | `xr` / `yr` nos dados | disco desenhado visível? | astro pintado na faixa de montanha | astro visível na batalha (x, y) | encruzilhada | veredito |
|---|---|---|---|---|---|---|
| 1 fields | 0,79 / 0,14 | não (0 px magenta em 8 andares + encruzilhada: a faixa opaca cobre o céu todo) | nenhum | nenhum | nenhum | sem astro na tela; a luz pintada nas montanhas (faces claras à direita) bate com `xr` 0,79 |
| 2 highlands | 0,74 / 0,24 | não (0 px) | nenhuma lua | nenhum | nenhum | sem astro na tela; nada contradiz |
| 3 abyss | 0,68 / 0,34 | não (0 px) | sol no vale, u = 0,505 da PNG (também no `_front`) | 0,51 / 0,30 (atrás da placa de intenção) | ~0,50 | DIVERGE: e o sol pintado ANDA 0,125 da largura por andar (andar 1 em 0,51, andar 4 em ~0,13, andar 6 de volta pela direita, com o reflexo da faixa espelhada) |
| 4 frost | 0,80 / 0,26 | não (0 px) | nenhum | nenhum | nenhum | sem astro na tela |
| 5 marsh | 0,72 / 0,27 | não (0 px) | nenhuma lua | nenhum | nenhum | sem astro na tela |
| 6 dusk | 0,30 / 0,38 | não (0 px) | sol grande, u = 0,505 | 0,51 / 0,20 | 0,47 | DIVERGE: luz pela esquerda (0,30), sol visível no centro; e o sol anda: andares 1-8 em 0,50 · 0,38 · 0,25 · 0,13 · 0,03+0,96 · 0,87 · 0,75 · 0,67 |

O ato 6 medido pelo lead (~0,55) é o andar 1 com outra largura de faixa; o problema real é maior: a
faixa de montanha rola com a câmera (`off = camZ × 2,5 × sx`, espelhada a cada ladrilho), então o
sol pintado atravessa a tela inteira a cada 8 andares, e numa run jogada o `camZ` acumula entre atos.
Nenhum `xr` fixo podia bater com ele.

## Depois

Regra nova: bioma com astro PINTADO declara `celestial.painted = u` (posição do astro na PNG da
faixa). A faixa de montanha desse bioma (base e `_front`, mesma transformação) deixa de rolar e é
ancorada para o astro pintado cair exatamente em `xr` (astro no infinito não tem paralaxe). O disco
desenhado não é desenhado nesses biomas. `xr` continua a fonte única da luz (sombra, `flipToSun`,
lado do castelo).

| bioma | `xr` / `yr` | astro visível na batalha (x) | andares 1-8 (x) | encruzilhada (x) | lado da luz mudou? |
|---|---|---|---|---|---|
| 1 fields | 0,79 / 0,14 (igual) | nenhum | nenhum | nenhum | não |
| 2 highlands | 0,74 / 0,24 (igual) | nenhum | nenhum | nenhum | não |
| 3 abyss | 0,63 / 0,47 | 0,63 (à direita da placa de intenção, agora visível) | 0,63 em todos | 0,63 | não (continua à direita) |
| 4 frost | 0,80 / 0,26 (igual) | nenhum | nenhum | nenhum | não |
| 5 marsh | 0,72 / 0,27 (igual) | nenhum | nenhum | nenhum | não |
| 6 dusk | 0,40 / 0,37 | 0,395 | 0,40 em todos (andares 6-8 o castelo cobre parte do disco) | 0,40 | não (continua à esquerda) |

Contraluz: os dois sóis ficam perto do centro, de propósito (a arte foi pintada assim), com uma
inclinação leve para o lado em que já estavam: abyss 0,63 (direita), dusk 0,40 (esquerda). As sombras
saem para a câmera e abrem para fora do sol (tip = (x - sol) / meia largura: na beira da estrada
±0,5 a ±0,7). Como o lado não mudou, nenhum PNG, quadro de `anim/`, `lightWindows`, `LANDMARK_SMOKE`
ou `world_props.lit` precisou ser re-espelhado; a direção do castelo (`dir` pelo lado de `xr`) é a mesma.

## Folhas
- `b<N>_<bioma>_batalha.png`: antes|depois, tod 0,65 (cima) e 0,95 (baixo); triângulo amarelo = `xr`
  com a linha da luz até o inimigo, círculo ciano = astro visível.
- `b<N>_<bioma>_encruzilhada.png`: idem na encruzilhada.
- `deriva_b3_abyss_andares.png`, `deriva_b6_dusk_andares.png`: andares 1 a 8, antes (sol andando) |
  depois (sol parado no `xr`).
