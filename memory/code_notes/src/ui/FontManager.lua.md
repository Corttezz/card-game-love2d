---
name: code_notes/src/ui/FontManager.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/FontManager.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/FontManager.lua`

Origem: `src/ui/FontManager.lua` em `7dbdb60d` (5 de 12 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-6 (junto a `local FontManager = {}`)

> src/ui/FontManager.lua
> Loader cacheado da fonte pixel default do jogo.
> Aponta pra assets/fonts/pixel.ttf ("Grimoire Pixel": Press Start 2P, OFL, com as
> maiusculas acentuadas redesenhadas por tools/font_latin_caps.py). Todos os call sites
> usam getFont/getResponsiveFont e ganham visual pixel automaticamente.
> Fallback: se o TTF falhar, cai no default do LÖVE com warning no console.

## L15 (em `fontCache`, junto a `local UiScale`)

> carregado sob demanda (evita ciclo de require)

## L26-28 (em `ttfExists`, junto a `function FontManager.setFontPath(path)`)

> Define um TTF alternativo (para idiomas com glifos fora do ASCII/latim,
> como CJK ou cirilico). Limpa cache e re-resolve disponibilidade.
> Passar nil ou string vazia volta pro pixel.ttf default.

## L44-51 (em `FontManager:new`, junto a `function FontManager.getFont(size)`)

> Obtém fonte pixel no tamanho pedido. Cache por tamanho.
> `setFilter("nearest", ...)` é crítico — sem isso a fonte fica borrada
> mesmo sendo pixel TTF.
>
> Dentro do contexto da escala de UI (src/ui/UiScale.lua) a fonte nasce com
> `dpiscale` = escala corrente: métricas continuam em unidades lógicas (o
> layout não muda), mas o glifo é rasterizado no tamanho FINAL — texto
> nítido em 1440p/4K em vez de um bitmap de 12px esticado.

## L97-101 (em `FontManager.getCacheStats`, junto a `local OUTLINE_OFFSETS_4 = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }`)

> Desenha `text` em (x, y) com outline preto offset pra legibilidade em qualquer fundo.
> color: {r,g,b,a} do texto principal (default branco).
> outlineAlpha: alpha do outline preto (default 0.9).
> diagonals: se true, usa 8-offset (mais bold); se false/nil, 4-offset padrão.
> Assume que a fonte correta já foi setada via setFont — a função não troca fonte.

