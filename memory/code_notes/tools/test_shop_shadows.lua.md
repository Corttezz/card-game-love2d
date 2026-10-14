---
name: code_notes/tools/test_shop_shadows.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_shop_shadows.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_shop_shadows.lua`

Origem: `tools/test_shop_shadows.lua` em `7dbdb60d` (3 de 10 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-24 (junto a `local TK = require("tools.testkit")`)

> tools/test_shop_shadows.lua
> Trava da SOMBRA PROJETADA dos objetos do Balcão do Mercador (Loja v5 r4):
> a sombra É a silhueta do sprite deitada no plano da mesa, não uma faixa.
>
> 1. shader == referência em Lua (ShopPerspective.castShadowRef) pixel a
> pixel: IoU >= 0,97 pra cada objeto (10 relíquias, pacote, sino, copo);
> 2. toda a sombra DENTRO da máscara do tampo (tableMask) e da caixa
> castShadowBox (o recorte da passada cobre a sombra);
> 3. sem "arco": nenhum pixel de sombra acima da reta da base da própria
> coluna, nada à esquerda da pegada (a luz vem da esquerda);
> 4. achatada e deitada: altura da sombra entre 20% e 45% da altura do
> objeto, comprimento pra direita >= 40% da altura; nunca retângulo
> (preenchimento da caixa < 90%);
> 5. a sombra VARIA com o objeto: larguras e contagens distintas
> (tesoura != sino != pacote);
> 6. objeto levantado (poção no hover): a sombra se desloca pela mesma
> projeção (lean*lift, dy*lift), fica mais rala e sem linha de contato;
> 7. linha de contato: 1 px sólido logo abaixo do contorno de baixo, só
> onde o objeto encosta;
> 8. performance: shader compilado uma vez, ~0 KB alocados por sombra
> (uniforms reutilizados), e na cena real as sombras saem TODAS antes
> do primeiro objeto da mesa (passada própria).
>
> CARDGAME_HEADLESS=1 love . test_one test_shop_shadows

## L76-77 (em `M.run`, junto a `t:truthy(("%s: deitada pra direita: alcance %d >= 25%% da altura %d"):format(name, reach, H),`)

> (o alcance é o do ponto mais alto da silhueta, que raramente fica na
> borda direita do sprite: por isso 25%, não lean*H)

## L118-119 (em `o1`, junto a `local dx, dy = b1.x0 - b0.x0, b1.y0 - b0.y0`)

> o canto de cima-esquerda da sombra (base do objeto) anda (lean, dy) x lift;
> a ponta de baixo não serve de medida: a aresta da frente corta

