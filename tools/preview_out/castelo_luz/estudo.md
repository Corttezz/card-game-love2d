# Estudo: luz do castelo, fim da estrada e curvatura (23/Out/2026)

Queixa do dono: em todos os atos o castelo joga luz na estrada mesmo lá longe (pior no ato 6), e o fim de toda estrada tem uma faixa escura que não parece natural. A esfera percorrida perde a impressão de curva.

Medição: `lovec . test_one screenshot_castelo_luz <rotulo>` (1920x1080, 6 atos, progresso 0 / 0,3 / 0,6 / 0,75 / 0,8125 / 0,875 / 0,9 / 1,0, horários 0,65 / 0,85 / 1,0). Para cada quadro o mesmo frame é desenhado duas vezes, com e sem as luzes do castelo (`WorldRoad.castleLights = false`), e a diferença é medida na faixa de chão logo à frente da crista (largura do castelo, 18% da altura, a partir de crista+4 px para absorver o balanço da sala). `medidas_antes.csv` e `medidas_depois.csv` têm tudo.

Referência de progresso: andar N do ato = progresso (N-1)/8. Andar 8 (chefe) = 0,875; a viagem do andar 7 para o 8 vai de 0,75 a 0,875; a cerimônia da porta vem depois.

## Inventário das fontes de luz e de "coisas que parecem luz"

| Fonte | Onde | Quando deveria existir | Antes | Depois |
|---|---|---|---|---|
| Janelas do castelo (glow dither + núcleo micro, z=999) | `src/ui/WorldRoad.lua` laço `lightWindows` em `drawCastleOf` (~2490) | No sprite sempre; no chão nunca, o castelo está além da crista | Círculo de raio 0,26 da largura do castelo: as janelas baixas (portão: marsh 0,97, abismo 0,85, dusk 0,88, frost 0,76, highlands 0,64) caíam na estrada em QUALQUER progresso. Ato 6: até 11.800 px acesos, média +1,25/255; marsh +0,5 a +1,4; abismo +0,8; frost +0,6; highlands só no progresso 0 | Sprite idêntico (mesma luz, mesmo z). O chão abaixo da crista é zerado pelo oclusor de horizonte: 0 px acesos em todo progresso < 0,75, nos 6 atos e 3 horários |
| Luz do portão no chão (nova) | `WorldRoad.GATE_SPILL` + submit em `drawCastleOf` | Só na chegada (viagem 7 para 8, chefe, porta) | Não existia como coisa própria: era o vazamento acima | Elipse rasa (sy 0,30) sob as janelas de portão (a[2] >= 0,75), intensidade 0,30, entra por smoothstep 0,74 a 0,875 (`castleSpillK`), +60% com a porta abrindo. Fields não tem janela de portão, então não tem poça |
| Sombra de contato do castelo na crista (`hillShadow`, disco de `ContactShadow`) | era `drawCastleOf` + `scene_integration.landmarks.castle.hillShadow` | Nunca: o pé do castelo está atrás do horizonte | Disco escuro da largura de 0,84 do castelo, 6 a 26 px de altura, logo abaixo da crista, em todos os atos e todo progresso: ERA a "faixa escura no fim da estrada" (perfil da estrada ato 1 chefe: 28 > 21 > 28 em 12 px) | Removido (código e dado) |
| Névoa baixa na base do castelo (`drawLowFog`, progresso > 0,55) | `drawCastleOf` ~2465 | Na base do sprite | Desenhada ANTES do domo: a parte abaixo da crista fica coberta. Não vaza | Igual |
| Faixa de névoa da crista e haze (gradientes 0,16 e 0,26) | `WorldRoad.draw` ~5054 a 5090 | Céu e silhueta | Desenhados antes do domo: só aparecem acima da crista. Não vazam | Igual |
| Postes da beira (LuminaireEngine: chama + poça no chão) | `engine/LuminaireEngine.lua:326`, chamados de `drawProps` | Do lado de cá, pela distância | Corretos (z = rel do poste, do lado de cá) | Igual (fora do escopo, frente do lead) |
| Poste emergindo atrás da crista | `drawPropsBehind` ~2667 | Só quando a chama já passou da crista; a luz não pode descer além da crista | A chama ABAIXO da crista (ainda escondida) já acendia, e o raio descia sobre o chão do lado de cá | Só acende com a chama visível; raio limitado à distância até a crista, então cresce conforme a chama sobe (sem salto) |
| Marcos: porta da loja (`windowGlow`), `selfLight`, fogueira/lanterna (`submitLandmarkLight`) | `WorldRoad.lua:1544`, `1592` | Do lado de cá, z = rel do marco | Marcos só são desenhados com rel <= crista: não vazam | Igual |
| Vagalumes e brasas do clima | `engine/WeatherEngine.lua:571/577/647` | Do lado de cá | Partículas vivem até a crista, z = rel ou -1: não vazam | Igual |
| Bichinhos que brilham à noite | `WorldRoad.draw` ~5130 | Do lado de cá | yr dentro do chão: não vazam | Igual |
| Brilho do inimigo (EnemyEmissives) e oclusores | `drawEncounterFront`, `EnemyRenderer` | Do inimigo | Não mexido (frente entradas-motor) | Igual |
| Fumaça do topo do castelo | `WorldRoad.update` | Só perto (progresso > 0,55) | É partícula, não luz | Igual |

## Correção

1. **Oclusor de horizonte** (`WorldRoad._horizonLight`, chamado logo depois do domo): faixas que seguem a curva da crista no lightmap, z = 998 (logo abaixo das janelas do castelo, z = 999, e acima de tudo que está do lado de cá). Resultado: nada que está além da crista (o castelo) ilumina o chão do lado de cá. Tudo do lado de cá (postes, vagalumes, inimigo) desenha depois e continua igual. Força o composite mesmo de dia com uma micro-luz de intensidade 0, para a curva valer em qualquer horário.
2. **Luz do portão própria e por distância**, em vez do círculo da janela: fade suave pelo progresso, nunca pop (trava monotônica no teste).
3. **Sombra de contato do castelo removida** (a faixa escura).
4. **Curvatura**: as mesmas faixas do horizonte carregam uma borda de 1 célula do lightmap (4 px) com luz de céu (ambiente x1,08) e depois 4 degraus muito leves (0,935 > 0,955 > 0,972 > 0,988, 12 px cada em 1000 px de altura): o chão e a estrada perdem um pouco de luz ao chegar na crista e a crista vira linha de horizonte. Degraus de 2% ficam abaixo do que o olho lê como faixa; o teste mede a subida de brilho em 12 px no fim da estrada e exige até 12% do brilho de referência (o disco antigo dava ~25%: 21 > 28 em 12 px no ato 1).

## Números (noite, tod 1,0, px acesos na frente da crista, antes > depois)

| Ato | longe (0) | 0,3 | meio (0,6) | andar 7 (0,75) | chefe (0,875) |
|---|---|---|---|---|---|
| 1 fields | 0 > 0 | 0 > 0 | 0 > 0 | 0 > 0 | 0 > 0 |
| 2 highlands | 1768 > 0 | 176 > 0 | 0 > 0 | 0 > 0 | 0 > 0 |
| 3 abyss | 11626 > 0 | 17609 > 0 | 24887 > 0 | 25652 > 0 | 22349 > 12080 (poça do portão) |
| 4 frost | 4362 > 0 | 5651 > 0 | 6525 > 0 | 6716 > 0 | 6271 > 3376 |
| 5 marsh | 8624 > 0 | 15912 > 0 | 31973 > 0 | 41269 > 0 | 48855 > 4096 |
| 6 dusk | 7891 > 0 | 11694 > 0 | 19436 > 0 | 23892 > 0 | 27705 > 3520 |

## O que ainda não está perfeito

- O lightmap é 1/4: a borda do horizonte é uma escada de 4 px seguindo a curva (lê como pixel art, mas é a resolução do lightmap, não da arte).
- A estrada já escurecia uns 6% perto da crista pela própria textura; somado ao degrau novo a queda total é de 10 a 18% em 60 px, gradual.
- A porta do marsh no meio da cerimônia (doorK 0,5) mostra um retângulo verde-limão chapado no portão (arte da animação da porta, não luz). Fora do escopo; anotado para quem cuida das portas.
- Sem `ContactShadow` no castelo, o pé dele na crista depende só da arte e dos tufos (`requireTufts`).

## Provas

- `atoN_antes_depois_noite.png`: em cima antes, embaixo depois; colunas longe / 0,3 / meio / andar 7 / chefe / porta; recorte 420x260 em 1:1 centrado na base do castelo.
- `atoN_depois_3horas.png`: depois, linhas tod 0,65 / 0,85 / 1,0.
- Trava: `love . test_one test_castle_light` (castelo longe não acende o chão, chegada sobe sem recuar nem saltar, fim da estrada sem faixa escura).
