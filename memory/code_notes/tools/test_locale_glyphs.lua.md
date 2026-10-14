---
name: code_notes/tools/test_locale_glyphs.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_locale_glyphs.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_locale_glyphs.lua`

Origem: `tools/test_locale_glyphs.lua` em `7dbdb60d` (3 de 5 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-10 (junto a `local M = {}`)

> tools/test_locale_glyphs.lua
> Todo caractere de TODO texto dos 5 locales existe na fonte do jogo?
>
> Glifo ausente no Press Start 2P não dá erro: a LÖVE desenha um vazio (ou
> um quadrado) e a frase sai com buraco — "¿Salir del juego?" virando
> " Salir del juego?". Ninguém percebe olhando código; só o jogador de
> espanhol/alemão/francês percebe, na tela. Esta trava percorre as tabelas
> inteiras e pergunta à fonte REAL (`Font:hasGlyphs`) caractere por caractere.
>
> Roda: love . test_one test_locale_glyphs

## L44 (em `M.run`, junto a `t:falsy("sonda: a fonte NAO tem ideograma (prova que hasGlyphs mede)",`)

> A sonda funciona? (sem isto um hasGlyphs sempre-true passaria verde)

## L80 (em `entries`, junto a `local HintBar = require("src.ui.HintBar")`)

> Truncamento da HintBar nunca deixa UTF-8 quebrado (crash da LÖVE).

