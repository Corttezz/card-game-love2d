---
name: code_notes/components/DeckViewerScreen.lua
description: Comentários com decisão/regra/histórico colhidos de components/DeckViewerScreen.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `components/DeckViewerScreen.lua`

Origem: `components/DeckViewerScreen.lua` em `7dbdb60d` (13 de 38 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-10 (junto a `local DeckViewerScreen = {}`)

> components/DeckViewerScreen.lua
> DECK VIEWER GLOBAL — tela CHEIA (não-modal) do deck da run, no estilo da
> aba de Coleção. Pesquisa (StS mods): "ver o deck inteiro numa tela ampla,
> passar o mouse pra ver descrição/nível de forja" é o QoL mais pedido do
> gênero. Reescrito Jul/2026 (feedback: "ocupar praticamente a tela inteira,
> tipo a aba de coleção, não um modal").
>
> Abrir: clique no deck da TopBar OU tecla D (combate). ESC/D/X fecha.
> Mostra o deck COM forja aplicada (valor verde + gemas), grid rolável,
> hover levanta a carta + moldura dourada + tooltip completo.

## L40 (em `instance._cardRects`, junto a `instance.cardInfo = require("src.ui.CardInfoDisplay"):new()`)

> Tooltip completo no hover (StS-style: descrição + raridade + forja)

## L42-43 (em `instance._cardRects`, junto a `instance.inspectModal = require("src.ui.CardInspectModal"):new()`)

> Modal de inspeção completo (igual à aba de Coleção): clicar numa carta
> abre a carta grande + painel detalhado, navegável por setas.

## L60-61 (em `list`, junto a `local id = type(entry) == "table" and entry.id or entry`)

> currentDeck guarda id string OU {id, edition, seal} (booster com
> edition/seal). Normaliza pro id — senão a carta some do visualizador.

## L65-66 (em `list`, junto a `local lvl = self.game.runManager:getEntryLevel(entry)`)

> Nivel POR COPIA (RunManager, secao "Forja POR COPIA"): duas
> copias da mesma carta podem estar em niveis diferentes.

## L105 (em `DeckViewerScreen:show`, junto a `self.inspectModal.card = nil`)

> garante que o modal de inspeção não reaparece de uma abertura anterior

## L124-126 (em `DeckViewerScreen:isVisible`, junto a `function DeckViewerScreen:resize()`)

> Resize NÃO zera a rolagem: o draw recalcula maxScroll e reclampa a cada
> frame, então a posição de leitura sobrevive a fullscreen/arrasto de borda
> (antes voltava pro topo — mesmo padrão do RunJournalScreen).

## L158 (em `DeckViewerScreen:wheelmoved`, junto a `if self.inspectModal:isVisible() then return true end`)

> modal trava scroll

## L193-195 (em `DeckViewerScreen:mousereleased`, junto a `if love.timer.getTime() - (self._openedAt or 0) < 0.25 then`)

> BUG playtest Jul/2026: o RELEASE do MESMO clique que abriu (press na
> TopBar) era roteado pra cá e fechava no mesmo frame. Ignora releases
> logo após a abertura.

## L224-225 (em `DeckViewerScreen:draw`, junto a `self.inspectModal:update(love.timer.getDelta())`)

> DeckViewer não é atualizado pelo main.lua (só desenhado) — tico o fade do
> modal aqui mesmo, com o delta do frame.

## L280-281 (em `DeckViewerScreen:draw`, junto a `local hot = (not modalOpen)`)

> Modal de inspeção aberto suprime o hover do X (igual ao grid) — o
> botão acendia POR BAIXO da carta ampliada.

## L302-304 (em `DeckViewerScreen:draw`, junto a `local dt = love.timer.getDelta()`)

> Render IDÊNTICO à Coleção (CardGridRender + interpolação _cardAnim):
> hover levanta/inclina a carta com warp 3D + sombra direcional + ícone
> vivo — SEM borda (a borda anterior estava errada; a Coleção não tem).

## L389 (em `hoverStr`, junto a `if hovered and not modalOpen then`)

> Tooltip completo no hover (só quando o modal NÃO está aberto).

