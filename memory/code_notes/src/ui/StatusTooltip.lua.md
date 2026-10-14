---
name: code_notes/src/ui/StatusTooltip.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/StatusTooltip.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/StatusTooltip.lua`

Origem: `src/ui/StatusTooltip.lua` em `7dbdb60d` (15 de 31 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-16 (junto a `local FontManager = require("src.ui.FontManager")`)

> src/ui/StatusTooltip.lua
> Tooltip global (singleton) pra status effects e elementos de UI. Qualquer
> componente chama StatusTooltip.show(name, mx, my, ctx) e o main.lua desenha
> no fim do frame (por cima de tudo) via StatusTooltip.draw().
>
> Resolve i18n `status.<name>.name` e `status.<name>.desc` com interpolação
> {stacks}/{duration}/etc. Se a chave não existir, cai em fallback: nome
> literal capitalizado + "".
>
> v2 (Jul/2026, playtest): textos vazavam do box em idiomas com palavras
> longas — a largura era medida só pelo TÍTULO. Agora o box é medido pelo
> CONTEÚDO real (wrap manual, maior linha define a largura, com teto), o
> título também quebra linha, e a tipografia ganhou respiro: line-height
> 1.4, letter spacing de 1px (pixel-art friendly) e padding maior. Pop-in
> sutil (fade+scale 0.14s) quando o tooltip troca de assunto; cantos
> ornamentais dourados pra organizar a moldura.

## L27-28 (em `StatusTooltip`, junto a `local shownKey = nil`)

> Pop-in: rastreia o "assunto" atual entre frames (o tooltip é ephemeral,
> mas o hover contínuo re-agenda o mesmo name — a animação persiste).

## L44-46 (em `setColor`, junto a `local function measureSpaced(font, text)`)

> ===== Tipografia com letter spacing =====
> LÖVE não tem letter spacing nativo: medimos e desenhamos char a char
> (UTF-8 safe). Medida e desenho usam a MESMA soma — nunca divergem.

## L67 (em `printSpaced`, junto a `local function breakLongWord(font, word, maxW, lines)`)

> Quebra palavra gigante (compostos alemães etc.) por caracteres.

## L82-83 (em `breakLongWord`, junto a `local function wrapSpaced(font, text, maxW)`)

> Wrap por palavras medindo COM letter spacing (getWrap nativo não sabe do
> spacing — era uma das fontes do vazamento).

## L107-109 (em `lines`, junto a `function StatusTooltip.show(statusName, mouseX, mouseY, ctx)`)

> Agenda um tooltip pra draw neste frame. Chamar ANTES do final do frame;
> múltiplas chamadas no mesmo frame: só a última desenha (normal pra hover).
> ctx: valores usados na interpolação ({stacks}, {duration}, ...).

## L117-118 (em `active`, junto a `k = require("src.ui.UiScale").activeK(),`)

> escala de UI de quem pediu (src/ui/UiScale): o desenho acontece
> depois, fora daquele contexto, e precisa voltar pro mesmo espaço

## L121-122 (em `active`, junto a `local now = love.timer.getTime()`)

> Assunto novo OU hover que saiu e voltou (gap > 0.25s) → reinicia o
> pop-in. Hover contínuo no mesmo assunto: animação segue de onde está.

## L146-150 (em `capitalize`, junto a `local warnedVariant = {}`)

> Resolve textos via I18n, com fallbacks sãos.
> ctx.variant escolhe uma VARIAÇÃO da descrição: `status.<x>.desc_<variant>`.
> Nasceu do estado permanente (joker/passiva), onde interpolar {duration} de
> um buff de 99 turnos imprimia "dura 99 turno(s)" — mentira com cara de dado.
> Variante ausente cai na desc normal (e avisa, ui_layout_invariants §3).

## L153-154 (em `resolveTexts`, junto a `if ctx and ctx.title then return ctx.title, ctx.body or "" end`)

> Texto JÁ composto pelo chamador (tooltip do intent do inimigo: nome do
> golpe + linhas montadas dos números congelados — EnemyHud).

## L157-158 (em `resolveTexts`, junto a `if I18n.t("status." .. statusName .. ".name", nil, "") == ""`)

> Status do kit dos inimigos (Frágil, Revoada, Eclipse, DoT no jogador)
> moram em `enemy_kit.status` — arquivo próprio por locale.

## L209 (em `StatusTooltip._draw`, junto a `local headerLines = wrapSpaced(headerFont, name, MAX_INNER)`)

> ===== MEDIDA pelo conteúdo real =====

## L244 (em `StatusTooltip._draw`, junto a `local rm = _G.gameSettings and _G.gameSettings.reducedMotion`)

> ===== POP-IN (fade + scale sutil; reduced motion pula) =====

## L255-256 (em `StatusTooltip._draw`, junto a `local ox = (x > active.x) and x or (x + boxW)`)

> Origem do scale no canto do box mais próximo do mouse (cresce "saindo"
> do cursor, não do centro).

## L320-322 (em `StatusTooltip._draw`, junto a `active = nil`)

> Auto-hide: tooltip é ephemeral por frame. Componentes têm que chamar
> show() a cada frame que o hover continua. Sem re-call, some no próximo
> frame automaticamente (shownKey/shownAt guardam a animação do assunto).

