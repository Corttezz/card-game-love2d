---
name: code_notes/tools/screenshot_achievements.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_achievements.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_achievements.lua`

Origem: `tools/screenshot_achievements.lua` em `7dbdb60d` (1 de 5 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-17 (junto a `local M = {}`)

> tools/screenshot_achievements.lua
> Galeria de conquistas + toast, em varios tamanhos e idiomas.
>
> love . screenshot_achievements            -> pt_BR, 4 tamanhos + toast
> love . screenshot_achievements de         -> um idioma, 4 tamanhos
> love . screenshot_achievements all        -> os 5 idiomas em 1280x720
>
> Saida: achievements_<locale>_<W>x<H>.png e achievements_toast_<locale>.png
> no save dir (CARDGAME_IDENTITY isola).
>
> Tamanho FALSIFICADO: desenha num Canvas WxH com love.graphics.getWidth/
> getHeight sobrescritos — love.window.setMode repetido dentro de tool trava
> (CLAUDE.md, resize). A galeria e o toast leem a janela so por essas duas
> funcoes, entao o resultado e o mesmo de uma janela real desse tamanho.
>
> Estado: ~metade liberada (com data), contadores parciais (barras), e uma
> secreta bloqueada + uma secreta liberada — todos os estados de celula.

