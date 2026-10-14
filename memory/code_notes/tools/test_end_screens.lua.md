---
name: code_notes/tools/test_end_screens.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_end_screens.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_end_screens.lua`

Origem: `tools/test_end_screens.lua` em `7dbdb60d` (2 de 13 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-9 (junto a `local TK = require("tools.testkit")`)

> tools/test_end_screens.lua
> Telas finais v2 (auditoria Out/2026): botões que respondem a mouse,
> teclado e gamepad, e layout por zonas que não se sobrepõe em nenhum
> tamanho (janela falsificada, como test_journal_resize) nem idioma.
>
> Antes: game over e vitória só aceitavam TECLA (o clique não fazia nada e o
> gamepad também não), e o texto do rodapé era a única instrução.
>
> love . test_one test_end_screens

## L62 (em `onEndless`, junto a `for _, loc in ipairs(LOCALES) do`)

> ===== Layout: zonas sem sobreposição em todo tamanho e idioma =====

