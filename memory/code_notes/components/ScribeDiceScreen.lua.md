---
name: code_notes/components/ScribeDiceScreen.lua
description: Comentários com decisão/regra/histórico colhidos de components/ScribeDiceScreen.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `components/ScribeDiceScreen.lua`

Origem: `components/ScribeDiceScreen.lua` em `7dbdb60d` (12 de 36 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-14 (junto a `local Button      = require("components.Button")`)

> components/ScribeDiceScreen.lua
> Tela do mini-jogo DADOS DO ESCRIBA (Out/2026). Modal sobre a loja; a
> regra, as odds e o save moram em src/systems/ScribeDice.lua.
>
> LAYOUT = ZONAS (CLAUDE.md §9): título → mesa (copo + dados) → linha de
> estado → apostas → fichas → ações. Cada elemento pertence a UMA banda;
> quando falta altura, quem cede é a ESCALA da mesa, nunca a posição das
> bandas. `ScribeDiceScreen.layout(sw, sh)` é puro e `validate()` confere
> (tools/test_scribe_dice roda os dois em vários tamanhos). O layout é
> recalculado a cada frame a partir da janela ATUAL, então resize é de graça.
>
> ENTRADA: mouse, e teclado/gamepad via MenuKit (cima/baixo troca de
> fileira, esquerda/direita escolhe, Enter confirma, Esc sai). O gamepad
> chega aqui já traduzido em tecla pelo main.lua.

## L50-52 (em `fitFont`, junto a `function ScribeDiceScreen.layout(sw, sh)`)

> ===========================================================================
> LAYOUT PURO
> ===========================================================================

## L55-56 (em `ScribeDiceScreen.layout`, junto a `local big = sw >= 1600 and sh >= 900`)

> Tela grande: o modal cresce junto (em 1920 o texto das odds a 8px era
> o número mais importante da tela e o menor).

## L78-79 (em `L.title`, junto a `local hr = big and 12 or 9`)

> "?" da explicação (Tutorial "dice_help") no canto direito da banda do
> título; o título centraliza no que sobra dos dois lados.

## L107-108 (em `L.roll`, junto a `function ScribeDiceScreen.validate(L, sw, sh)`)

> Problemas do layout (lista vazia = ok): tudo dentro do painel e da tela,
> e nenhuma banda invade outra.

## L146-148 (em `all`, junto a `function ScribeDiceScreen:new()`)

> ===========================================================================
> CICLO
> ===========================================================================

## L188-189 (em `ScribeDiceScreen:hide`, junto a `self.rolling = nil`)

> O jogador não fecha no meio da rolagem (botão e teclado travam lá);
> se alguém de fora fechar (voltar ao menu), o resultado já está salvo.

## L231-232 (em `self.flash`, junto a `if self.game and self.game.checkpointRun then self.game:checkpointRun() end`)

> O RESULTADO VAI PRO SAVE AGORA, antes de qualquer pixel revelar a
> soma: fechar o jogo no meio da rolagem não desfaz a aposta.

## L304-306 (em `leaveR`, junto a `local function printCentered(text, r, font, color, alpha)`)

> ===========================================================================
> DESENHO
> ===========================================================================

## L391-392 (em `ScribeDiceScreen:_drawStake`, junto a `local afford = used or self:_gold() >= value`)

> Depois da jogada a ficha escolhida é HISTÓRICO, não oferta: não pinta
> de vermelho "sem ouro" o valor que o jogador acabou de pagar.

## L485-487 (em `ScribeDiceScreen:draw`, junto a `function ScribeDiceScreen:mousepressed(x, y, button)`)

> ===========================================================================
> ENTRADA
> ===========================================================================

## L495-496 (em `ScribeDiceScreen:mousepressed`, junto a `function ScribeDiceScreen:openHelp()`)

> Abre a explicação dos dados (conversa do corvo "dice_help"), a qualquer
> momento: antes, depois da jogada, com as dicas desligadas.

