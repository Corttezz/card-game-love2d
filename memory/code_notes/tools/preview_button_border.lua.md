---
name: code_notes/tools/preview_button_border.lua
description: Comentários com decisão/regra/histórico colhidos de tools/preview_button_border.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/preview_button_border.lua`

Origem: `tools/preview_button_border.lua` em `7dbdb60d` (3 de 4 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-11 (junto a `local M = {}`)

> tools/preview_button_border.lua
> Comparação controlada da borda do Button: versão ANTIGA (traço interno
> quadrado em meio-pixel) vs ATUAL (traço interno seguindo a curva, em pixel
> inteiro). Nasceu da queixa "o botão Resgatar tem uma borda estranha".
>
> Desenha as duas na MESMA tela, nos 3 estados que mudam a paleta (normal /
> hover / disabled), e amplia 6x com nearest — a única forma honesta de julgar
> 1px de borda (memory/card_feel §v3.1: validar por PIXEL, não por código).
>
> Roda: love . preview_button_border
> Saída: button_border_cmp.png no diretório de save do LÖVE.

## L22-23 (em `M`, junto a `local function drawLegacyInner(x, y, w, h, border)`)

> Reprodução FIEL do traço interno como era antes do fix (Button.lua:451-454
> no commit anterior): rectangle("line") QUADRADO, ancorado em .5.

## L50-52 (em `states`, junto a `if col == 1 then`)

> Coluna 1 = ANTES: repinta o traço interno legado por cima. A
> borda nova fica embaixo, mas o legado é mais claro e grosso, e
> é exatamente a camada em disputa — é ela que se quer comparar.

