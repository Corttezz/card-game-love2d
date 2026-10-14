---
name: code_notes/tools/screenshot_pause.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_pause.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_pause.lua`

Origem: `tools/screenshot_pause.lua` em `7dbdb60d` (4 de 6 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-11 (junto a `local M = {}`)

> tools/screenshot_pause.lua
> Capturas do MENU DE PAUSA e das CONFIGURAÇÕES (components/PauseMenu.lua +
> components/SettingsMenu.lua) em VÁRIOS tamanhos de janela num só processo.
>
> love . screenshot_pause            → pause_<estado>_<W>x<H>.png
> love . screenshot_pause - de       → mesmo, em outro idioma
>
> Truque de captura: em vez de love.window.setMode (repetido dentro de tool
> TRAVA — memory/ui_layout_invariants.md §2), renderiza num CANVAS do tamanho
> alvo com love.graphics.getWidth/getHeight FALSIFICADOS. Todo layout das
> duas telas deriva dessas funções, então a captura é fiel ao jogo.

## L31-32 (em `love.graphics.getHeight`, junto a `local function drawBackdrop(w, h)`)

> Fundo "de jogo" barato: gradiente escuro + faixas, pra o véu do modal ter
> algo atrás (preto liso esconde se o véu está forte/fraco demais).

## L55-56 (em `capture`, junto a `local function settle(screen, secs)`)

> Avança animação de entrada até assentar (as telas usam love.timer.getTime
> só pra ruído; o estado de animação é do update(dt)).

## L99 (em `M.run`, junto a `if pause.armAbandon then pause:armAbandon() else`)

> Confirmação de abandono armada.

