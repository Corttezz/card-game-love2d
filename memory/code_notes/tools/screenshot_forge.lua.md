---
name: code_notes/tools/screenshot_forge.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_forge.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_forge.lua`

Origem: `tools/screenshot_forge.lua` em `7dbdb60d` (11 de 17 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-24 (junto a `local M = {}`)

> tools/screenshot_forge.lua
> Valida a BIGORNA (RestScreen no modo picker): grade de CARTAS REAIS com
> hover 3D, painel de preview de ganho ancorado na carta, e a CERIMÔNIA de
> forja — pose herói + 3 marteladas + PLACA DE DELTA ("ATQ 8 -> 10").
>
> love . screenshot_forge
> → forge_idle.png         grade ociosa
> → forge_hover.png        mouse sobre uma carta: lift + painel de preview
> → forge_anticipation.png carta subindo pra pose herói, placa com o ANTES
> → forge_clang.png        1a martelada (decalque + faíscas)
> → forge_turn.png         A VIRADA: valor antigo cede, novo em pop dourado
> → forge_stamp.png        3a martelada: o selo "+N" carimba
> → forge_settled.png      assentado e legível
>
> Timeline esperada (t = 0 no clique; constantes FORGE_T do RestScreen):
> 0.34 lift completo · 0.46 clang1 · 0.74 clang2 = VIRADA
> 1.00 clang3 = selo · 1.22 settle · ~2.57 fecha
>
> Padrão herdado de tools/screenshot_rewards.lua: o DRAW roda a cada frame
> simulado porque Card:draw MUTA estado da carta (grava self.x/y) — sem
> desenhar por frame o simulador não reproduz feedback loops de layout.
>
> Arg de ferramenta seta _G.HEADLESS_TOOL=true (main.lua) → saves vão pra
> *.tool.lua e o run.save.lua do jogador não é tocado.

## L39-40 (em `M`, junto a `local fakeMouse = { x = -999, y = -999 }`)

> Mouse "virtual": o simulador headless não move o cursor de verdade, então
> monkey-patcha love.mouse.getPosition (é o que RestScreen:update consulta).

## L50-54 (em `love.mouse.getPosition`, junto a `local function applyWindowSize(w, h)`)

> love . screenshot_forge [largura altura]
> O tamanho é OPCIONAL e aplicado UMA ÚNICA VEZ, antes de qualquer desenho.
> memory/ui_layout_invariants.md registra que setMode REPETIDO dentro de um
> tool trava (e pedir janela maior que o desktop trava na 1ª chamada), então
> aqui é uma chamada só e o valor é clampado à área útil.

## L65-69 (em `applyWindowSize`, junto a `function M.run(argW, argH, locale)`)

> argW/argH: tamanho da janela (opcional). locale: nil (pt_BR) | en/es/fr/de.
> O locale explicito existe pra VALIDAR A TRADUCAO: e em idioma estrangeiro
> que o PT cravado aparece — capturar so em pt_BR esconde justamente o defeito
> que se quer pegar. (E preciso passar explicitamente: tool de screenshot
> forca pt_BR, senao o sandbox herdaria settings.tool.lua em qualquer idioma.)

## L83-86 (em `M.run`, junto a `local CardDatabase = require("src.systems.CardDatabase")`)

> Deck de teste: o starter tem só 2 cartas. Injeta cartas FORJÁVEIS do
> catálogo (ordenadas por id pra a captura ser determinística) até ter
> material suficiente pra grade — e uma já forjada, pra validar o selo
> "+N" e a linha "Forja +1 -> +2" do painel de hover.

## L95-96 (em `pool`, junto a `local cd = CardDatabase:getCard(id)`)

> Joker NUNCA entra em currentDeck (invariante do projeto: vive em
> currentRun.jokers via Game:addJokerToRun).

## L103-106 (em `pool`, junto a `game.runManager:addCardToDeck("warrior_strike")`)

> CÓPIAS REPETIDAS do MESMO id: a queixa do dono ("se eu tiver duas
> cartas iguais, na tela de forjar só aparece uma"). O deck de teste
> carrega 3 cópias de warrior_strike de propósito — a grade tem que
> mostrar as TRÊS, e forjar uma não pode mexer nas outras duas.

## L110-112 (em `pool`, junto a `local firstIdx = nil`)

> Uma carta já forjada (mostra o selo +1 e o preview partindo de +1).
> É a PRIMEIRA cópia de warrior_strike: com o nível por cópia, a grade
> mostra "+1" em UMA das três e "+0" nas outras duas.

## L166-168 (em `capture`, junto a `local target = nil`)

> Hover na ULTIMA copia de warrior_strike (a 3a das tres injetadas acima).
> E de proposito uma COPIA REPETIDA: a cerimonia que vem a seguir forja
> ESSA, e as outras duas tem que ficar paradas onde estavam.

## L202-204 (em `out`, junto a `local beforeLvl = game.runManager:getUpgradesAt(target.idx)`)

> Confirma a forja na carta em hover.
> getUpgradesAt (a COPIA) e nao getUpgrades (o maior entre as copias do
> mesmo id) — senao a linha mentiria: outra copia ja estava em +1.

## L225-226 (em `out`, junto a `local function beat(label)`)

> `target` é a MESMA table guardada em screen.cardEntries, e a cerimônia
> troca entry.inst/entry.level in-place — então isto observa o swap.

