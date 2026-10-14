---
name: code_notes/tools/test_shop_scene.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_shop_scene.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_shop_scene.lua`

Origem: `tools/test_shop_scene.lua` em `7dbdb60d` (11 de 28 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-20 (junto a `local TK = require("tools.testkit")`)

> tools/test_shop_scene.lua
> Trava de COMPORTAMENTO do Balcão do Mercador em perspectiva (Loja v3b,
> src/ui/shop/ShopScene + ShelfItem + CardRewardScreen modo shop).
>
> 1. entrada: os objetos deslizam pra mesa e a tela espelha as cartas; o
> pergaminho nasce com a primeira oferta SELECIONADA e o COMPRAR armado;
> 2. hover (v5): NADA levanta (carta nem objeto): o ponto de apoio fica
> parado; a carta gira em torno da base (tilt com a base presa); som de
> hover UMA vez na borda, nunca durante o deslize da tela;
> 3. clique SELECIONA (não compra): pergaminho + brilho + COMPRAR · $N;
> 4. sem ouro: COMPRAR apagado e a compra pelo botão não passa, a placa
> treme (deny), sem toast;
> 5. compra pelo COMPRAR: objeto some (VENDIDO), voa pro destino certo
> (carta → deck na TopBar; relíquia → painel do jogador; pacote → abre a
> tela do pacote, sem voo); o pergaminho passa pra próxima oferta;
> 6. sino: objetos saem deslizando e os novos entram; VENDIDO não sobrevive;
> 7. reducedMotion: nada se move, mas preço, VENDIDO e foco continuam;
> 8. teclado: alvos do NavCursor pra cada objeto, COMPRAR, CONTINUAR, sino.
>
> love . test_one test_shop_scene

## L135-136 (em `playSound`, junto a `local ShelfItem = require("src.ui.shop.ShelfItem")`)

> Loja "reta": hover sem torção (ângulo da base igual ao repouso) e
> sem salto: passo por quadro limitado, ida e volta pelo mesmo caminho

## L175-176 (em `hv`, junto a `t:falsy("comum sem gema", ShelfItem.showsGem("common"))`)

> PLAQUINHA DE PREÇO: um latão só; comum sem gema; valor legível
> (contraste >= 4,5) com e sem ouro

## L190-192 (em `hv`, junto a `local Card = require("src.cards.base.Card")`)

> Loja v4: TILT 3D do hover por cima da pose (a conta da mão,
> Card.hoverTilt). Mouse levado pro espaço da carta pela homografia
> de repouso: canto sup. direito -> (+1, -1); centro -> 0; sai -> 0.

## L215 (em `hoverAt`, junto a `hoverAt(0.92, 0.92, 1 / 60)`)

> amortecido: um quadro depois de trocar de canto ainda não chegou

## L221-222 (em `hoverAt`, junto a `local worstBase, topMove = 0, 0`)

> v5: BASE PRESA. O press do shader (espelho ShelfItem.warpUV) não
> mexe nenhum ponto da base em modo quad; o topo, sim.

## L272 (em `rec`, junto a `local ShopPerspective = require("src.ui.shop.ShopPerspective")`)

> nada flutua: todo pé de coluna encostado (e a sombra) DENTRO do tampo pintado

## L287 (em `rec`, junto a `local realEllipse = love.graphics.ellipse`)

> sombra de contato, nunca elipse

## L301 (em `names`, junto a `local packIt = itemOf(screen, function(it) return it.kind == "pack" end)`)

> v5 r2: o pacote FLUTUA no hover (dono); a etiqueta balança

## L363-364 (em `rec`, junto a `t:truthy("sem ouro: latao da plaquinha muda de tom",`)

> v5: a plaquinha sem ouro troca de TOM (latão oxidado), não só a cor
> do texto; e a fita do COMPRAR lê o ouro no próprio desenho

## L523-528 (em `has`, junto a `_G.gameSettings.reducedMotion = false`)

> ================= 9. pergaminho (v5): textos longos nos 5 idiomas =================
> Para cada idioma e tamanho, as ofertas da vitrine + as 12 cartas de
> DESCRIÇÃO mais longa do jogo naquele idioma: o conteúdo inteiro
> cabe no miolo do pergaminho (acima do COMPRAR), sem cortar texto e
> sem descer a descrição abaixo de 8 px. O preço não se repete na
> legenda (está no COMPRAR). O CRT recebe a zona de leitura.

