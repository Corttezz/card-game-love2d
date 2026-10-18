# Item 3: poça de luz das luminárias que EMITE

## Defeito
O LightEngine só multiplica: ao entardecer (tod 0,85) a poça de `light.pool` no lightmap só devolve a arte até o
valor dela, então no chão escuro quase não aparecia (`antes_*` nos recortes). Duas luminárias de fogo nem tinham
poça: a lanterna do dusk e o braseiro do frost.

## Solução
`LuminaireEngine.drawPool`, chamado pelo `drawProps` no slot de profundidade da luminária, ANTES do sprite dela:
um passe aditivo (`shaders/light_emit.glsl`) só no chão, em 3 degraus com Bayer 4x4 em células de 4 px (mesmo
grão do lightmap), cor da chama, escalado por `dayK` (zero de dia, cresce até o fim do entardecer) e pelo
flicker da chama. A metade de trás da elipse é 2,2x mais curta (`upK`): o chão atrás da base é o que objetos do
fundo cobrem na tela, então a poça não sobe neles. Desenhado na ordem do painter: o poste, a grama e os props da
frente cobrem a poça; o lightmap multiplica por cima depois (a poça herda a luz do ambiente). Nunca toca céu,
silhueta de sprite nem HUD. `LuminaireEngine.EMIT` (intensidade 0,22, raio 0,75 da poça do lightmap, 3 níveis)
calibrado olhando os recortes 1:1: a primeira calibração (0,34 e 0,95) lia como holofote amarelado e pintava a
moita atrás do poste do ato 1.

Poça nova no catálogo: lanterna do dusk (raio 1,10) e braseiro do frost (1,40); valem também para o lightmap.

"Borda quente dos vizinhos" NÃO foi feita como aditivo: aditivo em silhueta de sprite é exatamente o que
`memory/lighting_engine.md` proíbe ("gradiente colado em silhueta", 4 tentativas removidas no v7). Os vizinhos
seguem aquecidos pelo lightmap multiplicativo; o que mudou neles é o chão iluminado até a base.

## Custo (perf_probe 1920x1080, tod 1, duas rodadas, mediana do frame)
| bioma | draws antes -> depois | ms desligado | ms ligado |
|---|---|---|---|
| fields | 375 -> 376 | 3,29 / 3,47 | 3,07 / 3,19 |
| highlands | 405 -> 407 | 3,43 / 6,18 | 3,56 / 3,53 |
| abyss | 418 -> 420 | 3,56 / 3,70 | 3,39 / 3,46 |
| frost | 390 -> 392 | 3,42 / 3,89 | 4,02 / 3,32 |
| marsh | 434 -> 435 | 3,73 / 3,80 | 3,85 / 3,96 |
| dusk | 350 -> 351 | 2,95 / 3,14 | 2,96 / 2,96 |

+1 a +2 draw calls (uma por luminária com poça na tela) e +2 a +4 trocas de shader; o tempo ficou dentro do ruído
da máquina (a GPU é compartilhada com outras frentes; a diferença média entre ligado e desligado é negativa).

Recortes `b<N>_recorte.png` (antes|depois em tod 0,65, 0,85 e 1,0, 1:1) e quadros inteiros `b<N>_batalha.png`.
Trava `test_light_emit` (de dia nada, à noite acende, pico ≤ 0,35, ≤ 4 níveis, mais chão na frente que atrás,
cresce com o entardecer, desliga com a iluminação).
