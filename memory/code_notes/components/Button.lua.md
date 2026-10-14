---
name: code_notes/components/Button.lua
description: Comentários com decisão/regra/histórico colhidos de components/Button.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `components/Button.lua`

Origem: `components/Button.lua` em `7dbdb60d` (23 de 56 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-20 (junto a `local Palette     = require("src.ui.Palette")`)

> components/Button.lua
> BotÃ£o em estilo "Balatro meets grimoire": retÃ¢ngulo sÃ³lido com cantos cortados,
> emboss 1px (highlight top/left + shadow bottom/right), scale-on-hover,
> press squish. MantÃ©m a paleta grimÃ³rio existente + juice_up do engine.
>
> Refactor baseado em UIBox_button do Balatro (functions/UI_definitions.lua:6376).
> Substitui a versÃ£o antiga com 4 rivets + dual outline + stripes (muito detalhe).
>
> ESTADOS visuais:
> normal   â†’ fill base + emboss + shadow
> hover    â†’ scale 1.05 + fill mais quente + emboss brighter + pulse sutil
> pressed  â†’ scale 0.96 + shadow reduzida + fill afundada
> disabled â†’ steel palette + sem emboss + sem hover
>
> VARIANTS:
> "clean"     (default)    Look novo Balatro-inspired
> "ornate"    (legacy)     Rivets + stripes + dual outline (look antigo)
> "invisible" (hit-only)   SÃ³ hit area, sem render
>
> API compatÃ­vel com versÃ£o anterior (Button:new(x, y, w, h, text, onClick, color?, fontSize?))

## L36-37 (em `Button`, junto a `Button.CORNER_RADIUS = 2`)

> Radius do corner cut (em pixels lÃ³gicos). Balatro usa r=0.1 (~6-8px numa tela
> 720p). Em pixel art 2-3 Ã© o sweet spot.

## L59-60 (em `Button:new`, junto a `btn._hoverScale = 1.0`)

> Scale animations (Balatro-style): hover escala pra 1.05, press squish pra 0.96.
> Eased exp decay pra nÃ£o saltar.

## L64-65 (em `Button:new`, junto a `btn.onePress = false`)

> one_press: bloqueia trigger apÃ³s 1 click. Usado pra botÃµes que mudam state
> (evita duplo click disparando 2x). setOnePress(true) pra ativar.

## L86-87 (em `Button:update`, junto a `if self.variant ~= "invisible" then`)

> Variant "invisible" = button invisÃ­vel sobre uma carta (CardRewardScreen,
> pack open). NÃƒO toca menuHover â€” a carta jÃ¡ toca hoverCard, evita som duplo.

## L89-90 (em `Button:update`, junto a `Sfx.playWithVariation("menuHover", 1.0, 0.12)`)

> Pitch random pra evitar fadiga auditiva ao hoverar vÃ¡rios botÃµes
> em sequÃªncia (Balatro engine/text.lua:201 pattern).

## L93-94 (em `Button:update`, junto a `Moveable.juice_up(self, 0.05, 0.03)`)

> Hover-enter juice (Balatro card.lua:4307): kick sutil de scale
> pra carta/botÃ£o "saltar" ao mouse passar.

## L100 (em `Button:update`, junto a `require("src.ui.CursorManager").request("hand")`)

> cursor vira "mÃ£o" sobre qualquer botÃ£o vivo (pedido por frame)

## L116-122 (em `Button:update`, junto a `local SCHEMES = {`)

> Retorna {fill, fillHi, fillLo, border, text, textShadow, shadow} pro estado atual.
> fillHi = emboss top/left (highlight)
> fillLo = emboss bottom/right (sombra interna)
> ColorScheme override: Button:setColorScheme("green" | "red") aplica paleta
> alternativa pra mini-buttons (Buy verde / Cancel vermelho Balatro-style).
> MantÃ©m comportamento de hover/pressed mas troca fill/border/text por cores
> semÃ¢nticas em vez do dourado padrÃ£o.

## L243-245 (em `autoIconScale`, junto a `local MIN_FONT = 8`)

> Fit de texto com DUPLO fallback: (1) desce o tamanho da fonte atÃ© MIN_FONT;
> (2) se nem na mÃ­nima couber, TRUNCA com reticÃªncias (UTF-8 safe). Contrato
> do componente: texto NUNCA vaza de um Button, em idioma nenhum.

## L277-278 (em `Button:draw`, junto a `if not self.disabled and not self._consumed then`)

> alvo de navegação por teclado/pad (src/ui/NavCursor) — inclusive o
> invisível (hitbox de cartão/linha que a tela desenha por conta própria)

## L286-287 (em `Button:draw`, junto a `return self:_drawClean()`)

> "ornate" foi aposentada no design system Jul/2026 (zero call sites);
> variant desconhecida cai no clean.

## L291-294 (em `Button:draw`, junto a `function Button:_drawTv()`)

> Look "menu de TV" (Menu v2.1, docs/plan/menu-crt-v2.md): item de LISTA,
> nÃ£o caixa de aÃ§o â€” backing translÃºcido com accent dourado Ã  esquerda;
> hover = barra de fÃ³sforo Ã‚MBAR preenchida com texto ink (a linguagem
> de seleÃ§Ã£o de menu de televisor). Texto alinhado Ã  ESQUERDA.

## L395-401 (em `Button:_drawClean`, junto a `local pressing = self.pressed and self.hover and not self.disabled`)

> ===== SHADOW (drop shadow abaixo + direita) =====
> Parallax: shadow distance encolhe quando pressed (Balatro engine/ui.lua:683-686).
> Default 3,3; press com hover â†’ 0,0 (visualmente "afunda" no fundo).
> O fill do botÃ£o tambÃ©m se desloca +1,+1 pra completar a sensaÃ§Ã£o de press.
> Aplicamos x/y nudge ao botÃ£o inteiro (fill+emboss+border+icon+text), mas
> mantemos a sombra nas coords originais â€” assim a sombra "fica pra trÃ¡s"
> enquanto o botÃ£o afunda.

## L410 (em `Button:_drawClean`, junto a `x = x + fillNudge`)

> Aplica nudge a TODO o resto do botÃ£o somando ao x/y locais.

## L417-419 (em `Button:_drawClean`, junto a `if c.fillHi then`)

> ===== GRADIENTE sutil (upgrade Jul/2026 — "botão chapado é feio") =====
> Metade de cima levemente mais clara + faixa de baixo mais escura:
> o fill ganha volume sem mudar a paleta nem a geometria.

## L431-432 (em `Button:_drawClean`, junto a `if c.fillHi then`)

> ===== EMBOSS (top/left highlight) =====
> 1px horizontal no topo + 1px vertical na esquerda. Cria look 3D.

## L453-464 (em `Button:_drawClean`, junto a `PixelCanvas.rectRoundedOutline(x, y, w, h, r, c.border)`)

> ===== BORDER outline com cantos cortados + linha interna =====
> Borda DUPLA (upgrade Jul/2026): outline externo + traço interno mais
> escuro — mesma linguagem dos painéis (UiPanel) e das molduras de carta.
>
> FIX Set/2026 (o dono: "o botão Resgatar tem uma borda estranha"): o
> traço interno era um `rectangle("line", x + 2.5, ...)` — QUADRADO dentro
> de um outline ARREDONDADO e ancorado em meio-pixel. Dois defeitos que se
> somavam: nos quatro cantos a linha reta cruzava a curva do outline
> externo (o "canto duplo" que se via), e o .5 num render nearest saía
> borrado e mais grosso que 1px — lia como adesivo colado, não moldura.
> A identidade (cor, recuo ~2px, alpha 0.8) é a MESMA; só agora o traço
> segue a mesma curva e assenta em pixel inteiro, como todo o resto da UI.

## L469 (em `Button:_drawClean`, junto a `if self.hover and not self.disabled and not self._consumed then`)

> ===== HOVER PULSE sutil =====

## L515-519 (em `Button:_drawClean`, junto a `function Button:mousepressed(mx, my, buttonId)`)

> Retorna true quando o button consumiu o clique (pressed=true). Callers
> usam esse return pra short-circuit e EVITAR fallthrough indesejado (ex:
> CardRewardScreen mousepressed limpava selection se nada consumisse â€” sem
> esse return, click no buy mini-button caÃ­a na desseleÃ§Ã£o e o onClick
> nunca disparava no mousereleased subsequente).

## L536-537 (em `Button:mousereleased`, junto a `if _G.jiggleScreen then _G.jiggleScreen(0.3) end`)

> Jiggle global no click (Balatro engine/ui.lua:990): empurra o
> screen-shake accumulator pra leve tremor de feedback tÃ¡til.

## L555-557 (em `Button:setVisible`, junto a `function Button:setColorScheme(scheme) self.colorScheme = scheme end`)

> Aplica esquema de cores semÃ¢ntico ("green" | "red" | nil = padrÃ£o dourado).
> Usado em mini-buttons compactos onde a cor comunica a aÃ§Ã£o (Buy = verde,
> Cancel = vermelho).

## L567-568 (em `Button:setVariant`, junto a `function Button:setOnePress(enabled)`)

> Ativa one_press: apÃ³s primeiro click, botÃ£o fica "consumed" (disabled visual,
> nÃ£o responde mais). Ideal pra botÃµes que iniciam transiÃ§Ã£o de state.

