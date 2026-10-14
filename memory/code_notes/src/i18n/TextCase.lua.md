---
name: code_notes/src/i18n/TextCase.lua
description: Comentários com decisão/regra/histórico colhidos de src/i18n/TextCase.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/i18n/TextCase.lua`

Origem: `src/i18n/TextCase.lua` em `7dbdb60d` (3 de 3 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-9 (junto a `local utf8 = require("utf8")`)

> src/i18n/TextCase.lua
> Caixa alta/baixa que entende ACENTO.
>
> `string.upper` do Lua trabalha byte a byte em ASCII: "légendaire":upper()
> vira "LéGENDAIRE", "não":upper() vira "NãO". Com os locales voltando a ter
> acento (Out/2026), todo rótulo que a UI força em maiúsculas (raridade, tipo
> de carta, botão PEGAR) passou a sair com a letra acentuada em minúscula no
> meio da palavra. Este módulo cobre o Latin-1 — exatamente o conjunto que a
> fonte desenha (tools/test_locale_glyphs.lua).

## L16-17 (em `TextCase`, junto a `for cp = 0xE0, 0xFE do`)

> Latin-1 suplementar: minúsculas U+00E0..U+00FE (exceto ÷ U+00F7) ↔
> maiúsculas U+00C0..U+00DE (exceto × U+00D7). ÿ/ß ficam como estão.

## L40 (em `parts`, junto a `print("[TextCase] texto com UTF-8 invalido: " .. s)`)

> UTF-8 inválido: devolve o ASCII convertido e AVISA (nunca calado).

