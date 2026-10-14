---
name: code_notes/src/data/scene_anchors.lua
description: Comentários com decisão/regra/histórico colhidos de src/data/scene_anchors.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/data/scene_anchors.lua`

Origem: `src/data/scene_anchors.lua` em `7dbdb60d` (10 de 11 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-45 (junto a `local SceneBackground = require("src.ui.SceneBackground")`)

> src/data/scene_anchors.lua
> ============================================================================
> ÂNCORA DE CHÃO DAS CENAS DE FUNDO (interiores)
> ============================================================================
> Defeito que originou a tabela (Set/2026): o inimigo era ancorado em
> `height * 0.68` — um número fixo, igual pra TODA cena. No `castle_hall_2`
> essa linha cai na PAREDE, acima da laje: o chefe do ato 2 ficava pairando
> no meio do salão com uma sombra de contato embaixo.
>
> 0.68 nunca foi "a altura do chão": era a altura do chão de UMA arte, herdada
> por todas as outras. Cada PNG tem o horizonte onde o artista pôs — então a
> linha de piso é DADO DA CENA, não constante do renderer.
>
> `yr` está em coordenadas NORMALIZADAS DA PNG, não da tela: o
> `SceneBackground` desenha em cover-fit e, em telas largas (16:9), CORTA a
> imagem na vertical. Converter via `SceneBackground.getCoverTransform`
> mantém o pé no mesmo ponto do piso em qualquer resolução.
>
> REFERÊNCIA DE ENQUADRAMENTO: na estrada o inimigo pisa em
> `WorldRoad.getRoadAnchor(BATTLE_REL, ...)` ≈ 76% da altura da tela. Os
> interiores ficam perto disso — quando a arte permite. O `castle_hall_2`
> tem a laje mais baixa que os outros dois e por isso pede um valor maior;
> forçá-lo aos 0.76 dos irmãos é exatamente o bug que começou tudo.
>
> Campos:
> xr, yr        ponto do chão onde o inimigo pisa (0..1 na PNG)
> shadowA       opacidade base da sombra de contato nessa cena
> lightXr       x normalizado da fonte de luz dominante da arte; a sombra
> de quem FLUTUA se desloca pro lado oposto (ver
> [[enemy_poses]] · [[shadow_engine]])
> lightBehind   true = luz vem do fundo da sala → sombra cai pro primeiro
> plano (pra baixo na tela)
> backYr        BORDA DE TRÁS do piso (0..1 na PNG): o mais ao fundo que o
> pé ainda pisa laje — acima disso é degrau, soleira ou
> parede. O PALCO da batalha (Out/2026, dono: "os inimigos
> param muito na frente da tela") recua o chefe de `yr` até
> no máximo aqui, pra sair de trás da carta em hover. Sem o
> campo = `yr` (não recua). Lido de olho em cada PNG.
> horizonYr     linha do olho da sala (default HORIZON_YR): recuar no
> piso encolhe o chefe na razão da distância até ela
> (depthSizeK) — a perspectiva de um chão plano.
>
> Ver [[ui_layout_invariants]] regra 3: cena sem entrada aqui usa o padrão
> e AVISA no console.
> ============================================================================

## L58-61 (em `SceneAnchors.BY_SCENE`, junto a `castle_hall_1 = { xr = 0.50, yr = 0.78, backYr = 0.72,`)

> ATO 1 — salão do rei-carniça (arte nova, Out/2026). O lajedo começa na
> soleira do vão âmbar (~0.70); 0.78 cai no tapete vermelho, e o recuo
> para em 0.72 — um passo À FRENTE da soleira, nunca dentro do vão.
> Seis arandelas nas colunas + vão claro ao fundo → sombra definida.

## L65-71 (em `castle_hall_1`, junto a `castle_hall_2 = { xr = 0.50, yr = 0.83, backYr = 0.83, deathYr = 0.885,`)

> ATO 2 — catedral roxa. A laje começa BEM mais baixa que nos irmãos
> (a parede e a porta ocupam até ~0.78): 0.83 é o primeiro ponto em que
> o pé realmente encosta na pedra. É a cena do defeito original.
> deathYr (Out/2026): 0.83 é a faixa estreita de pedra COLADA na base da
> parede/balaustrada (y 208-216 da PNG); o lich morto deitado ali lia
> "em cima do parapeito". O piso andável (mosaico) vai de 0.845 a 0.92
> — o cadáver de quem voa cai no meio dele (y 226). Só os mortos.

## L75-85 (em `castle_hall_2`, junto a `castle_hall_3 = { xr = 0.50, yr = 0.78, backYr = 0.73,`)

> ATO 3 — cidadela infernal (arte nova, Out/2026): portão-caveira com
> cascata de lava. A PNG gerada tinha o chão começando em 0.78 — em 16:9
> o teto da mão segurava o pé do tirano acima disso, e ele pairava DENTRO
> da cascata. 18 linhas da faixa vertical (pedestais/cascatas, 176-193)
> foram removidas e o rodapé espelhado: o basalto agora começa em ~0.71.
> Out/2026 (round 2, "o tirano está flutuando"): entre as bases dos
> pilares havia a POÇA de lava da cascata, e é exatamente ali (0.72-0.73)
> que o pé pousa — pé na frente de lava clara lê como flutuar. Pintada
> uma laje de basalto (y 176-187 da PNG) sobre a poça: o pé agora pisa
> pedra escura com a lava atrás e acima. Pedra → sombra de contato
> visível (antes 0.45, chão de lava).

## L89-95 (em `castle_hall_3`, junto a `castle_hall_4 = { xr = 0.50, yr = 0.78, backYr = 0.75,`)

> ATO 4 — cidadela glacial. A laje de gelo começa em ~0.72 (a soleira do
> arco escuro); 0.78 cai bem à frente dela, no ladrilho, igual aos halls
> 1 e 3. Luz de dois braseiros pálidos NA FRENTE das paredes laterais e
> do arco escuro ao fundo → sombra curta e definida sobre gelo polido.
> Out/2026: o pé pousava na soleira com o VÃO PRETO do arco logo atrás
> (parecia pairar); o piso de gelo agora continua pra dentro do arco em
> 4 degraus que escurecem (y 173-187 da PNG).

## L99-101 (em `castle_hall_4`, junto a `castle_hall_5 = { xr = 0.50, yr = 0.82, backYr = 0.79,`)

> ATO 5 — coração pútrido. O lajedo molhado só começa em ~0.755 (antes
> disso são as raízes e o vão preto): 0.82 é o primeiro ponto em que o pé
> pisa pedra de verdade. Chão alagado reflete → sombra de contato fraca.

## L105-108 (em `castle_hall_5`, junto a `castle_hall_6 = { xr = 0.50, yr = 0.78, backYr = 0.75,`)

> ATO 6 — corte do eclipse. O mármore da frente começa em ~0.73 (o vão
> claro morre na linha do chão); 0.78 fica no meio do espelho. A luz vem
> do FUNDO e é forte: a sombra cai pro primeiro plano e é bem marcada
> sobre pedra polida.

## L112-113 (em `castle_hall_6`, junto a `catacumbs   = { xr = 0.50, yr = 0.80, shadowA = 0.95,`)

> Cenas legadas do SceneLayer (fallback por ato quando o hall não
> existe, e caminho antigo de SCENE_MODE ~= "worldroad").

## L140-145 (em `SceneAnchors.get`, junto a `function SceneAnchors.groundAnchor(scene, width, height, yrOverride)`)

> Ponto de CHÃO da cena em pixels de tela, passando pelo MESMO cover-fit que
> `SceneBackground.draw` usa (em 16:9 a PNG é cortada na vertical — ignorar
> isso desancora o pé conforme o aspecto da janela).
> Retorna (x, y). Cai no padrão relativo à tela se a PNG não existir.
> yrOverride: outra linha da MESMA arte (backYr/horizonYr), pelo mesmo
> cover-fit.

## L159-161 (em `SceneAnchors.groundAnchor`, junto a `function SceneAnchors.depthSizeK(scene, width, height, fromY, toY, exp)`)

> Escala de quem recuou no piso de fromY (âncora da arte) até toY: num chão
> plano o tamanho é proporcional à distância até a linha do horizonte.
> `exp` amacia como na estrada (WorldRoad.ENEMY_SIZE_PERSP). Nunca aumenta.

