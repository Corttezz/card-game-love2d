---
name: code_notes/tools/screenshot_end_screens.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_end_screens.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_end_screens.lua`

Origem: `tools/screenshot_end_screens.lua` em `7dbdb60d` (1 de 3 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-9 (junto a `local TK = require("tools.testkit")`)

> tools/screenshot_end_screens.lua
> Captura as telas finais (game over + vitória) em vários idiomas e tamanhos,
> desenhando num canvas com getWidth/getHeight FALSIFICADOS (o mesmo truque
> do BOSS_ROOMS_VIRTUAL — setMode maior que o desktop trava).
>
> love . test_one screenshot_end_screens            → pt_BR + de, 3 tamanhos
> love . test_one screenshot_end_screens fr         → só um idioma
>
> Saída: end_<tipo>_<idioma>_<WxH>.png no diretório de save.

