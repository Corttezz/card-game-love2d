---
name: code_notes/components/MapScreen.lua
description: Comentários com decisão/regra/histórico colhidos de components/MapScreen.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `components/MapScreen.lua`

Origem: `components/MapScreen.lua` em `7dbdb60d` (14 de 34 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-7 (junto a `local MapScreen = {}`)

> components/MapScreen.lua
> Tela imersiva de escolha de caminho. Tela inteira dividida em N painéis
> verticais (N = #nodes). Cada painel mostra uma scene full-height ilustrada
> (assets/sprites/scenes/path_<type>.png) com overlay de número, nome e descrição.
>
> Hover: painel ganha brilho + leve zoom. Outros painéis ficam dim.
> Atalhos: 1/2/3 escolhem painel correspondente.

## L18-21 (em `MapScreen`, junto a `local enemyPreviewCache = {}`)

> Cache de sprites estáticos do inimigo (south.png) reaproveitando os assets
> já gerados pelo enemy pipeline. Mostrados como preview no MapScreen pra
> jogador antecipar qual inimigo vai enfrentar — uso real das rotações que
> antes eram só geradas e nunca renderizadas.

## L71-72 (em `instance.panelRects`, junto a `instance.chosenIdx = nil`)

> Fade-out animation: ao escolher node, outros ease alpha → 0.25 em 0.28s
> antes do callback disparar (Balatro decision-feedback pattern).

## L74 (em `instance.panelRects`, junto a `instance.dimOthers = 0`)

> 0 (todos full) → 1 (não-escolhidos a 25%)

## L101-102 (em `MapScreen:updateLayout`, junto a `local titleH = math.floor(sh * 0.10)`)

> Cada painel ocupa toda a altura e (sw / n) da largura.
> Reservar topo pra título (~10%) e bottom pra hint (~5%).

## L154-155 (em `drawPanelBackground`, junto a `love.graphics.setScissor(r.x, r.y, r.w, r.h)`)

> Scissor pra clipar dentro do painel (mais simples que stencil + funciona
> com Canvas do CRTShader sem precisar de stencil enabled).

## L168 (em `drawPanelBackground`, junto a `love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 0.7)`)

> Borda lateral entre painéis (linha vertical sutil)

## L219-220 (em `drawPanelOverlay`, junto a `local MapManager = require("src.systems.MapManager")`)

> labelFor/descFor e não node.label: um nó vindo do save carrega o texto
> do idioma em que foi gerado.

## L251-252 (em `MapScreen:draw`, junto a `local title = self.title or I18n.t("map.title", nil, "Escolha o proximo caminho")`)

> Titulo resolvido AQUI (nao no :new): a tela e criada uma vez no boot e
> sobrevive a troca de idioma nas configuracoes.

## L264-265 (em `MapScreen:draw`, junto a `local isCombat = (node.type == "battle" or node.type == "elite"`)

> PREVIEW DO INIMIGO: pra nodes de combate, sobrepor sprite south
> do inimigo que será enfrentado (usa os assets já gerados).

## L269-270 (em `MapScreen:draw`, junto a `local spriteId = node.enemyId`)

> O inimigo do nó já foi sorteado (EnemyRoster) — a prévia
> mostra exatamente quem vai lutar.

## L299-301 (em `MapScreen:draw`, junto a `if self.chosenIdx and self.chosenIdx ~= i and (self.dimOthers or 0) > 0 then`)

> Dim overlay sobre nodes NÃO-escolhidos enquanto a transição roda.
> Desenhado por cima de tudo que esse panel pintou, simulando "o
> jogador escolheu, esses caminhos ficam pra trás" (Balatro feel).

## L315-317 (em `MapScreen:draw`, junto a `love.graphics.setColor(1, 1, 1, 1)`)

> Sem faixa de dica no rodapé (pedido do dono, Out/2026: textos
> informativos poluíam a tela). Os marcos já se explicam no hover e as
> teclas 1/2/3 continuam funcionando — ver HintBar.ENABLED.

## L339-341 (em `MapScreen:mousepressed`, junto a `function MapScreen:_chooseNode(node, idx)`)

> Marca o node escolhido, ease alpha dos outros pra 0.25, e dispara callback
> após 0.28s. Replica decision-feedback Balatro: o jogador VÊ a escolha "afundar"
> antes do flow seguir, em vez de cortar abrupto.

