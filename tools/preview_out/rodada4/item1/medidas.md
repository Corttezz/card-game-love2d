# Item 1: montanhas paradas nos atos 3 e 6

Captura: `lovec . test_one screenshot_rodada4 <rotulo>:andares` (1920x1080, tod 0,65, andares 1 a 8, só o WorldRoad).
Medida do horizonte: deslocamento horizontal da faixa (linhas 200 a 420) do andar 1 para cada andar, por correlação.
Sol: `WorldRoad.sunXr()` (a mesma função que a luz, a sombra e o `flipToSun` leem) e o disco pintado achado
por gabarito na captura (só os andares 1 a 3 são limpos: do 4 em diante o castelo e as luminárias cobrem o disco
e o gabarito erra; o deslocamento do horizonte é a medida confiável).

## Antes (d63b5507)
| bioma | sol (px) andares 1..8 | horizonte andou (px, andar 1 -> 2..8) |
|---|---|---|
| abyss | 1210 em todos | 0, 0, 0, 0, 0, 0, -2 |
| dusk | 768 em todos | 0 em todos |

Faixa e sol parados no ato inteiro: a viagem não tinha horizonte se movendo.

## Depois
`celestial.drift` (abyss 0,035 em torno de xr 0,655; dusk 0,04 em torno de 0,40): a faixa (base e `_front`, mesmo
`stripTransform`) anda de `xr + drift` no andar 1 a `xr - drift` no andar 8, linear na viagem, e para no fim do ato.
A luz lê a posição real do sol pintado (`PropCut.sunXr`), então sol e luz andam juntos.

| bioma | sol `sunXr` (px) andares 1..8 | gabarito andares 1..3 | horizonte andou (px) |
|---|---|---|---|
| abyss | 1325, 1306, 1286, 1267, 1248, 1229, 1210, 1190 | 1327, 1307, 1287 | 20, 40, 58, 78, 96, 116, 134 |
| dusk | 845, 823, 801, 779, 757, 735, 713, 691 | 843, 821, (castelo) | 22, 44, 66, 90, 112, 134, 156 |

Horizonte andou o mesmo que o sol (134 contra 135 px no abyss, 156 contra 154 no dusk): o disco pintado continua
no ponto de onde a luz vem. Nenhum bioma troca de lado (abyss 0,62 a 0,69; dusk 0,36 a 0,44), então nada re-espelha.

A `_front` do dusk NÃO ganhou parallax próprio: ela é a mesma colina da faixa de fundo recortada sem céu, e andar
em velocidade diferente mostraria a colina de fundo saindo por trás da da frente (dupla). As duas andam juntas.

Folhas: `b3_andares_antes_depois.png`, `b6_andares_antes_depois.png` (andares 1, 4 e 8). Trava: `test_sky_strip`.
