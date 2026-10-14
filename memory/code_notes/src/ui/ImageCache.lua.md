---
name: code_notes/src/ui/ImageCache.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/ImageCache.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/ImageCache.lua`

Origem: `src/ui/ImageCache.lua` em `7dbdb60d` (3 de 8 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-3 (junto a `local ImageCache = {}`)

> src/ui/ImageCache.lua
> Cache global de imagens. Evita recarregar o mesmo PNG várias vezes.
> Use SEMPRE em vez de love.graphics.newImage direto quando o mesmo asset pode ser usado por múltiplas instâncias.

## L12-14 (em `missCache`, junto a `function ImageCache.get(path)`)

> Carrega (ou retorna do cache) uma imagem. Em erro, retorna fallback.
> O miss é CACHEADO e logado UMA vez — antes, um PNG faltando em tela
> (voucher da loja) re-tentava o disco e spammava o log a cada frame.

## L38-40 (em `ImageCache.get`, junto a `function ImageCache.tryGet(path)`)

> Como get(), mas retorna NIL no miss (sem fallback) — pra quem quer
> detectar "arte não existe" e desenhar o próprio fallback (voucher da
> loja mostrava theRock.png no lugar da arte que faltava).

