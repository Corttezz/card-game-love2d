---
name: code_notes/src/ui/MenuKit.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/MenuKit.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/MenuKit.lua`

Origem: `src/ui/MenuKit.lua` em `7dbdb60d` (5 de 10 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-15 (junto a `local Palette = require("src.ui.Palette")`)

> src/ui/MenuKit.lua
> Peças compartilhadas dos MODAIS DE SISTEMA navegáveis por teclado/gamepad
> (PauseMenu + SettingsMenu, Out/2026). Três coisas que as duas telas tinham
> que fazer IGUAL — e que antes nenhuma das duas fazia:
>
> 1. NAVEGAÇÃO: tecla → intenção ("up"/"down"/"left"/"right"/"confirm"/
> "back"/"tab_next"/"tab_prev"). WASD + setas + Enter/Espaço + Tab/Q/E.
> O gamepad chega aqui já traduzido em tecla (love.gamepadpressed no
> main.lua), então a tabela é a ÚNICA fonte do mapa de controles.
> 2. ENTRADA: o painel desce do topo com leve overshoot e o véu escurece
> junto (Balatro: o overlay "cai" no lugar — create_UIBox_generic_options
> entra por alignment offset). reducedMotion tira o MOVIMENTO, nunca o
> véu (memory/ui_layout_invariants.md §3: tira movimento, não informação).
> 3. FOCO: anel dourado pulsante em volta do item focado — o mesmo desenho
> em qualquer modal, pra quem joga no teclado saber ONDE está.

## L50-51 (em `shiftDown`, junto a `function MenuKit.enterEase(t)`)

> Progresso eased da entrada (0..1) a partir do tempo desde o show.
> easeOutBack suave: passa ~4% do lugar e assenta (o "cair" do Balatro).

## L63-64 (em `reducedMotion`, junto a `function MenuKit.drawVeil(t, alpha)`)

> Véu do modal: escurece junto com a entrada (sempre, mesmo com
> reducedMotion — o véu é informação "isto é modal", não movimento).

## L73 (em `MenuKit.drawVeil`, junto a `function MenuKit.pushEnter(t)`)

> Empurra a transformação da entrada. Sempre casar com love.graphics.pop().

## L81-82 (em `MenuKit.pushEnter`, junto a `function MenuKit.focusRing(x, y, w, h, time, pad)`)

> Anel de foco: contorno duplo dourado com respiração leve. `pad` afasta o
> anel do retângulo (default 3) pra não comer a borda do próprio item.

