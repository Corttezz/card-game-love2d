# Landmarks, castelos e poste do ato 1: julgamento diorama (18/Out/2026)

Método: cada sprite olhado a 1:1 e 4x (castelos 3x) em `antes/*_4x.png`, `antes/*_3x.png`, e na cena
(`screenshot_integracao_terreno` dia/meio/pôr × fork/landmark/viagem/castelo, batalha 1080p em tod 0,85).
Lado da luz medido no PNG (`lmd_lit`: diferença média de luminância metade direita menos metade
esquerda por linha da silhueta, sem pixels emissivos; > +0,04 = luz da direita, < -0,04 = da esquerda) e
conferido no olho. Luz do bioma = `celestial.xr`: sol/lua à DIREITA em fields, highlands, abyss, frost,
marsh; sol à ESQUERDA em dusk (0,30).

Vereditos: OK (fica), ESPELHO (arte boa, luz pintada contra o bioma: PNG e todos os quadros de `anim/`
espelhados, âncoras espelhadas), NOVA (regerada no PixelLab `create_image_pro`, arte atual como style image).

| Bioma | Objeto | Luz medida | Leitura diorama | Veredito |
|---|---|---|---|---|
| fields | battle (estandarte) | +0,01 | mastro com 2 tons, pano com dobras; fino por natureza | OK |
| fields | elite (obelisco) | -0,054 | duas faces, base com cristais; face clara à esquerda, contra o sol | ESPELHO |
| fields | event (tenda) | +0,053 | camadas (cortina na frente, mesa, interior), oclusão boa | OK |
| fields | rest (fogueira) | 0,00 | anel de pedras, lenha, saco ao lado | OK |
| fields | shop (+hover) | -0,087 | casa com volume e varanda; empena clara e parede da direita em sombra: luz à esquerda | ESPELHO (fumaça xf 0,325 → 0,675) |
| fields | castelo (+porta) | -0,044 | torres com volume, hera em camadas; todas as torres escuras à direita, contra o sol | ESPELHO (`lightWindows` espelhadas) |
| fields | poste `fields_lantern_0` | +0,046 | haste chapada de 4 px sem face de luz, lanterna 1/4 da altura, vidro creme que não lia aceso | NOVA |
| highlands | battle | -0,02 | estandarte | OK |
| highlands | elite (dólmen) | +0,035 | blocos com espessura, pedras caídas | OK |
| highlands | event (barraca) | +0,05 | toldo, figura atrás do balcão, lanternas penduradas | OK |
| highlands | rest (caldeirão-braseiro) | 0,00 | volume de bacia, pés | OK |
| highlands | shop (+hover) | +0,022 | casa de pedra azul com volume | OK |
| highlands | castelo (+porta) | -0,014 | sombras projetadas em cunha à DIREITA das torres: luz da esquerda, contra a lua | ESPELHO |
| abyss | battle | 0,00 | estandarte fino (25 px) | OK |
| abyss | elite (pilar de lava) | +0,079 | rachaduras, pedras em volta | OK |
| abyss | event (barraca) | 0,00 | cortina, figura, braseiro, pote na frente | OK |
| abyss | rest (lenha) | +0,02 | lenha e brasas | OK |
| abyss | shop (+hover) | -0,065 | casa de pedra e telhado vermelho; lado direito em sombra | ESPELHO (fumaça xf 0,230 → 0,770) |
| abyss | castelo (+porta) | 0,00 | luz vem da lava, neutro | OK |
| frost | battle | -0,063 | estandarte; face clara à esquerda | ESPELHO |
| frost | elite (pilar de gelo) | -0,070 | duas faces, face clara à esquerda | ESPELHO |
| frost | event (barraca nevada) | +0,017 | camadas, neve no telhado | OK |
| frost | rest | +0,016 | pedras do anel liam como almofadas brancas achatadas, sem lenha à vista | NOVA |
| frost | shop (+hover) | +0,040 | cabana de troncos, volume | OK |
| frost | castelo (+porta) | -0,014 | sombras à direita das torres: luz da esquerda; base de neve borrada (fica abaixo da crista) | ESPELHO |
| marsh | battle | +0,01 | estandarte em galho | OK |
| marsh | elite (totem) | -0,043 | cilindro liso de tronco, chapado, sem raiz nem camada | NOVA (espelhada para a lua à direita) |
| marsh | event | -0,03 | barraca com musgo, pote na frente | OK |
| marsh | rest | -0,02 | chama sobre mancha de brasa chapada, sem pedra nem lenha | NOVA (espelhada) |
| marsh | shop (+hover) | -0,007 | palafita com volume | OK |
| marsh | castelo (+porta) | -0,056 | faces claras à esquerda, contra a lua | ESPELHO |
| dusk | battle | +0,060 | estandarte, face clara à direita, contra o sol da esquerda | ESPELHO |
| dusk | elite (menir) | -0,066 | bloco empilhado de frente, chapado | NOVA (luz da esquerda, -0,11) |
| dusk | event | +0,008 | barraca com camadas | OK |
| dusk | rest | 0,00 | chama sobre gravetos chapados | NOVA |
| dusk | shop (+hover) | -0,043 | casa de palha, luz à esquerda (certo para o dusk) | OK |
| dusk | castelo (+porta) | +0,021 | torres claras à direita, contra o sol de `xr` 0,30 | ESPELHO (ver nota) |

## Arte nova (PixelLab `create_image_pro`, 6 chamadas, 96 candidatas)

- Poste dos campos: candidata `fl_lantern_a__11` (poste quadrado de ~5 px com face clara à direita, mão
  francesa fina, lanterna de 15 px numa haste de 68 = 0,22 da altura, pedras no pé). Vidro recolorido de
  creme para âmbar (o grade lavava o creme e o vidro não lia aceso). Cintilação refeita só no vidro
  (`tools/bake_luminaire_flicker.py fields_lantern_0 glow 0.45`). Luz: `intensity` 1,00 e `light.pool`
  1,20/1,10 (poça no chão).
- Fogueiras novas: marsh `ma_rest_a__8` (pedras com musgo, juncos, espelhada), dusk `du_rest_a__3`
  (anel de pedras e três toras), frost `fr_rest_a__1` (granito com neve, lenha). Chama tremulando por
  `bake_luminaire_flicker.py <nome> flame 0.75`.
- Elites novos: marsh `ma_elite_a__1` (toco com raízes, crânio de carneiro, musgo, runas verdes;
  espelhado), dusk `du_elite_a__2` (menir com runas douradas, pedras caídas, capim). Pulso das runas por
  `bake_luminaire_flicker.py <nome> glow 1.0`.
- `LANDMARK_SHADOW_PAD` das cinco artes novas = 1; perfil de pegada do dusk rest 0,25/0,28.

## Regra nova (motor, genérica)

Luminária de beira de estrada que cai entre 4,5 unidades à frente e 1,5 atrás do landmark escolhido é
afastada lateralmente até ficar a meia largura do landmark + meia largura dela + 3 % da tela. Resolve o
pilar-braseiro colado na fogueira do ato 3 (agora a ~210 px do centro do fogo em vez de ~150); a margem
de 8 % empurrava o poste do ato 6 para dentro da copa e foi descartada.

## Nota

No ato 6 o céu pintado tem um sol à direita (faixa que rola com a câmera) enquanto `celestial.xr` = 0,30
manda a luz pela esquerda; segui o dado, como as árvores do ato 6 (`lit = -1`). Fica a inconsistência do
céu, que não é escopo desta frente.
